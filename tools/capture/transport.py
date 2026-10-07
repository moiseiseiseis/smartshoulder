"""Fuentes de datos del reloj: BLE (bleak) y USB serial (pyserial).

Ambas corren en su propio hilo y publican mensajes en una queue.Queue que la UI lee:
  ("conn", bool, nombre)      conexión / desconexión
  ("samples", first_index, [crudos])
  ("status", dict)            STATUS del reloj
  ("battery", pct)
  ("log", texto)
"""
from __future__ import annotations

import asyncio
import queue
import threading

import serial
import serial.tools.list_ports
from bleak import BleakClient, BleakScanner

import contract as c


class BleSource:
    def __init__(self, out: queue.Queue):
        self.out = out
        self.loop = asyncio.new_event_loop()
        self.client: BleakClient | None = None
        self.raw_batch = 1
        threading.Thread(target=self.loop.run_forever, daemon=True).start()

    def _run(self, coro):
        return asyncio.run_coroutine_threadsafe(coro, self.loop)

    # ---------- API para la UI (no bloqueante) ----------
    def scan(self, callback):
        """Busca relojes SmartShoulder y llama callback([nombres]) desde el hilo BLE."""
        async def go():
            try:
                devices = await BleakScanner.discover(timeout=4.0)
            except Exception as e:
                self.out.put(("log", f"⚠ No se pudo buscar por Bluetooth: {e}. "
                                     "Revisa que el Bluetooth de la PC esté encendido."))
                devices = []
            callback(sorted({d.name for d in devices if d.name and d.name.startswith(c.NAME_PREFIX)}))
        self._run(go())

    def connect(self, name: str):
        self._run(self._connect(name))

    def disconnect(self):
        self._run(self._disconnect())

    def send(self, payload: bytes):
        self._run(self._send(payload))

    def start_capture(self, arm: int):
        self.send(bytes([c.CMD_SET_MODE, c.MODE_CAPTURE]))
        self.send(bytes([c.CMD_SET_ARM, arm]))
        self.send(bytes([c.CMD_START_SESSION, self.raw_batch]))

    def stop_capture(self):
        self.send(bytes([c.CMD_STOP_SESSION]))

    def identify(self):
        self.send(bytes([c.CMD_IDENTIFY]))

    # ---------- interno ----------
    async def _connect(self, name: str):
        try:
            self.out.put(("log", f"Conectando a {name}…"))
            device = await BleakScanner.find_device_by_name(name, timeout=8.0)
            if device is None:
                self.out.put(("log", f"No se encontró {name}"))
                return
            self.client = BleakClient(device, disconnected_callback=self._on_disconnect)
            await self.client.connect()
            mtu = self.client.mtu_size
            self.raw_batch = max(1, min(8, (mtu - 7) // 12))
            await self.client.start_notify(c.UUID_RAW_STREAM, self._on_raw)
            await self.client.start_notify(c.UUID_STATUS, self._on_status)
            await self.client.start_notify(c.UUID_BATTERY_LEVEL, self._on_battery)
            self._on_status(None, await self.client.read_gatt_char(c.UUID_STATUS))
            self._on_battery(None, await self.client.read_gatt_char(c.UUID_BATTERY_LEVEL))
            self.out.put(("log", f"Conectado. MTU {mtu} → {self.raw_batch} muestras por paquete"))
            self.out.put(("conn", True, name))
        except Exception as e:
            self.out.put(("log", f"Error al conectar: {e}"))
            self.out.put(("conn", False, name))

    async def _disconnect(self):
        if self.client:
            await self.client.disconnect()

    async def _send(self, payload: bytes):
        if not (self.client and self.client.is_connected):
            self.out.put(("log", "Sin conexión: comando no enviado"))
            return
        await self.client.write_gatt_char(c.UUID_CONTROL, payload, response=True)

    def _on_disconnect(self, _client):
        self.out.put(("conn", False, ""))
        self.out.put(("log", "Reloj desconectado"))

    def _on_raw(self, _char, data: bytearray):
        try:
            first, samples = c.parse_raw_packet(bytes(data))
            self.out.put(("samples", first, samples))
        except ValueError as e:
            self.out.put(("log", str(e)))

    def _on_status(self, _char, data):
        self.out.put(("status", c.parse_status(bytes(data))))

    def _on_battery(self, _char, data):
        self.out.put(("battery", data[0]))


class SerialSource:
    """Respaldo por cable USB: misma información que BLE, a través de la consola serial del firmware."""

    def __init__(self, out: queue.Queue):
        self.out = out
        self.port: serial.Serial | None = None

    @staticmethod
    def ports() -> list[str]:
        return [p.device for p in serial.tools.list_ports.comports()]

    def connect(self, port: str):
        try:
            self.port = serial.Serial(port, 115200, timeout=0.2)
            threading.Thread(target=self._reader, daemon=True).start()
            self.out.put(("conn", True, port))
            self.send_line("status")
        except serial.SerialException as e:
            self.out.put(("log", f"Error al abrir {port}: {e}"))

    def disconnect(self):
        if self.port:
            self.port.close()
            self.port = None
        self.out.put(("conn", False, ""))

    def send_line(self, line: str):
        if self.port:
            self.port.write((line + "\n").encode())

    def start_capture(self, arm: int):
        self.send_line("mode capture")
        self.send_line("arm L" if arm == c.ARM_LEFT else "arm R")
        self.send_line("start")

    def stop_capture(self):
        self.send_line("stop")

    def identify(self):
        self.send_line("identify")

    def _reader(self):
        while self.port and self.port.is_open:
            try:
                line = self.port.readline().decode(errors="replace").strip()
            except (serial.SerialException, OSError):
                self.out.put(("conn", False, ""))
                self.out.put(("log", "Puerto serial cerrado"))
                return
            if line.startswith("D,"):
                parts = line.split(",")
                if len(parts) == 8:
                    self.out.put(("samples", int(parts[1]), [tuple(int(v) for v in parts[2:])]))
            elif line:
                self.out.put(("log", line))
