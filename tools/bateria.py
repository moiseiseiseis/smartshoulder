"""Monitor de batería del reloj por USB: voltaje en tiempo real y tendencia.

  python tools/bateria.py                 # detecta el puerto solo, lee cada 5 s
  python tools/bateria.py --cada 10 --csv bateria.csv

Usa el comando de serial `status` del firmware. Ctrl+C para salir.
Ojo: con el USB conectado la lectura incluye el efecto del cargador; una LiPo sana cargando sube hacia ~4.2 V.
"""
from __future__ import annotations

import argparse
import re
import sys
import time
from collections import deque

import serial
import serial.tools.list_ports

SEEED_VID = 0x2886
RE_STATUS = re.compile(r"vbat=([\d.]+) bat%=(\d+)")
WINDOW_S = 300   # la lectura tiene ±0.01 V de ruido: la tendencia sale de una recta sobre 5 min


def slope_per_min(points: deque[tuple[float, float]]) -> float:
    """Pendiente por mínimos cuadrados, en V/min."""
    n = len(points)
    mt = sum(t for t, _ in points) / n
    mv = sum(v for _, v in points) / n
    den = sum((t - mt) ** 2 for t, _ in points)
    return sum((t - mt) * (v - mv) for t, v in points) / den * 60 if den else 0.0


def find_port() -> str | None:
    for p in serial.tools.list_ports.comports():
        if p.vid == SEEED_VID:
            return p.device
    return None


def read_status(s: serial.Serial) -> tuple[float, int] | None:
    s.reset_input_buffer()
    s.write(b"status\n")
    end = time.time() + 2
    while time.time() < end:
        m = RE_STATUS.search(s.readline().decode(errors="replace"))
        if m:
            return float(m.group(1)), int(m.group(2))
    return None


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", help="p. ej. COM5 (por defecto se detecta)")
    ap.add_argument("--cada", type=float, default=5.0, help="segundos entre lecturas")
    ap.add_argument("--csv", help="guardar lecturas en este archivo")
    a = ap.parse_args()

    csv = open(a.csv, "a", encoding="utf-8") if a.csv else None
    t0 = time.time()
    first: float | None = None
    recent: deque[tuple[float, float]] = deque()   # (t, v) de los últimos 5 min, para la pendiente
    s: serial.Serial | None = None
    print("Tiempo    Voltaje  Bat%  vs inicio  Tendencia (últimos 5 min)")
    try:
        while True:
            if s is None:
                port = a.port or find_port()
                if not port:
                    print("\r(esperando el reloj por USB...)", end="", flush=True)
                    time.sleep(2)
                    continue
                try:
                    s = serial.Serial(port, 115200, timeout=0.5)
                    time.sleep(1)
                except serial.SerialException:
                    time.sleep(2)
                    continue
            try:
                r = read_status(s)
            except serial.SerialException:
                print("\n(reloj desconectado)")
                s.close()
                s = None
                continue
            if r:
                v, pct = r
                now = time.time()
                first = v if first is None else first
                recent.append((now, v))
                while now - recent[0][0] > WINDOW_S:
                    recent.popleft()
                trend = "  ... (calculando, 1 min)"
                if now - recent[0][0] >= 60:
                    slope = slope_per_min(recent)
                    arrow = "↑ sube" if slope > 0.002 else "↓ baja" if slope < -0.002 else "→ estable"
                    trend = f"{arrow} ({slope * 1000:+.0f} mV/min)"
                el = int(now - t0)
                print(f"{el // 60:3d}:{el % 60:02d}   {v:.2f} V  {pct:3d}%  {v - first:+.2f} V   {trend}")
                if csv:
                    csv.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')},{v:.3f},{pct}\n")
                    csv.flush()
            time.sleep(a.cada)
    except KeyboardInterrupt:
        pass
    finally:
        if s:
            s.close()
        if csv:
            csv.close()


if __name__ == "__main__":
    main()
