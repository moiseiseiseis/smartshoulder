"""Contrato BLE de SmartShoulder (espejo de contracts/ble.md)."""
import struct

def _uuid(short: str) -> str:
    return f"0ed8{short}-8e11-4ac8-bea3-882874982696"

UUID_SERVICE = _uuid("0001")
UUID_CONTROL = _uuid("0002")
UUID_EVENTS = _uuid("0003")
UUID_RAW_STREAM = _uuid("0004")
UUID_STATUS = _uuid("0005")
UUID_BATTERY_LEVEL = "00002a19-0000-1000-8000-00805f9b34fb"

NAME_PREFIX = "SS-"

CMD_START_SESSION = 0x01
CMD_STOP_SESSION = 0x02
CMD_SET_ARM = 0x03
CMD_SET_MODE = 0x04
CMD_IDENTIFY = 0x07

ARM_RIGHT, ARM_LEFT = 0, 1
MODE_INFERENCE, MODE_CAPTURE = 0, 1

SAMPLE_PERIOD_MS = 20          # 50 Hz
ACCEL_SCALE_G = 0.000122       # ±4 g
GYRO_SCALE_DPS = 0.0175        # ±500 dps

EXERCISES = {
    0: "NULO",
    1: "Flexión anterior",
    2: "Abducción",
    3: "Rotación externa",
    4: "Rotación interna",
    5: "Extensión de tríceps",
    6: "Estabilización escapular",
}


def parse_raw_packet(data: bytes) -> tuple[int, list[tuple[int, ...]]]:
    """RAW_STREAM: u32 first_sample_index + N × 6 × i16 → (índice, [muestras crudas])."""
    if len(data) < 16 or (len(data) - 4) % 12:
        raise ValueError(f"paquete RAW de longitud inválida: {len(data)}")
    first = struct.unpack_from("<I", data, 0)[0]
    n = (len(data) - 4) // 12
    samples = [struct.unpack_from("<6h", data, 4 + 12 * i) for i in range(n)]
    return first, samples


def parse_status(data: bytes) -> dict:
    state, mode, arm, fw, model, batch = struct.unpack_from("<6B", data, 0)
    return {"state": state, "mode": mode, "arm": arm, "fw": fw, "model": model, "raw_batch": batch}


def to_physical(raw: tuple[int, ...]) -> tuple[float, ...]:
    """Crudo → (ax, ay, az en g; gx, gy, gz en dps)."""
    return tuple(v * ACCEL_SCALE_G for v in raw[:3]) + tuple(v * GYRO_SCALE_DPS for v in raw[3:])
