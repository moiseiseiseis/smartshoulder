"""Prueba de paridad firmware ↔ Python (contexto/02 §9): mismas muestras → mismas repeticiones.

  python -m smartshoulder_ml.parity --port COM5 --seconds 40 --expect 1

La XIAO (sesión iniciada por serial en modo inferencia) imprime cada muestra cruda `D,...` y cada `# REP n @índice`.
Aquí se cuenta de nuevo con smartshoulder_ml.repcounter sobre esas mismas muestras y se comparan los índices.
"""
from __future__ import annotations

import argparse
import re
import time

import numpy as np

from .config import GYRO_SCALE_DPS
from .repcounter import RepCounter

REP_RE = re.compile(r"# REP (\d+) @(\d+)")
EXPECTED_RE = re.compile(r"# EXPECTED (\d+) @(\d+)")


def capture(port: str, seconds: float, expect: int) -> tuple[list[tuple[int, list[int]]], list[int], list[str], int]:
    import serial

    s = serial.Serial(port, 115200, timeout=0.2)
    time.sleep(1.2)
    s.reset_input_buffer()
    for cmd in ("stop", "mode inference", "arm R", "start", f"expect {expect}"):
        s.write((cmd + "\n").encode())
        time.sleep(0.1)
    buf = b""
    t0 = time.time()
    while time.time() - t0 < seconds:
        buf += s.read(8192)
    s.write(b"stop\n")
    time.sleep(0.4)
    buf += s.read_all()
    s.close()

    samples, reps, info = [], [], []
    expect_from = 0
    for line in buf.decode(errors="replace").splitlines():
        if line.startswith("D,"):
            p = line.split(",")
            if len(p) == 8:
                samples.append((int(p[1]), [int(v) for v in p[2:]]))
        elif (m := REP_RE.match(line)):
            reps.append(int(m.group(2)))
        elif (m := EXPECTED_RE.match(line)):
            expect_from = int(m.group(2))   # el contador del firmware arranca en esta muestra
            info.append(line)
        elif line.startswith("#"):
            info.append(line)
    return samples, reps, info, expect_from


def python_reps(samples: list[tuple[int, list[int]]], start: int = 0) -> list[int]:
    """Mismas operaciones que el firmware: float32(crudo) × 0.0175f, desde la misma muestra que él."""
    rc = RepCounter()
    scale = np.float32(GYRO_SCALE_DPS)
    out = []
    for idx, raw in samples:
        if idx < start:
            continue
        g = np.array(raw[3:], np.float32) * scale
        if rc.update(g):
            out.append(idx)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="COM5")
    ap.add_argument("--seconds", type=float, default=30)
    ap.add_argument("--expect", type=int, default=1, help="exercise_id esperado (1 = flexión)")
    ap.add_argument("--save", help="guardar las muestras crudas en este CSV")
    a = ap.parse_args()

    samples, fw, info, expect_from = capture(a.port, a.seconds, a.expect)
    idx = [i for i, _ in samples]
    gaps = sum(1 for x, y in zip(idx, idx[1:]) if y != x + 1)
    py = python_reps(samples, expect_from)
    if a.save:
        np.savetxt(a.save, np.array([[i, *r] for i, r in samples]), fmt="%d", delimiter=",", header="index,ax,ay,az,gx,gy,gz", comments="")
    gyro = np.abs(np.array([r[3:] for _, r in samples], np.float32) * GYRO_SCALE_DPS) if samples else np.zeros((1, 3))
    print("\n".join(info))
    print(f"Giro máximo: {gyro.max():.0f} °/s · segundos con movimiento (> 25 °/s): {(gyro.max(axis=1) > 25).sum() / 50:.1f}")
    print(f"Muestras: {len(samples)} ({len(samples) / 50:.1f} s) · huecos en la captura serial: {gaps}")
    print(f"Repeticiones firmware: {len(fw)}  en {fw}")
    print(f"Repeticiones Python:   {len(py)}  en {py}")
    if gaps:
        print("⚠ Hubo huecos en la captura serial: la comparación no es válida, repite la prueba.")
    elif fw == py:
        print("✓ PARIDAD: el firmware y Python cuentan exactamente las mismas repeticiones en las mismas muestras.")
    else:
        print("✗ Sin paridad: revisar que repcounter.cpp y repcounter.py sean idénticos.")


if __name__ == "__main__":
    main()
