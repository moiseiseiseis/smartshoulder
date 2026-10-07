"""Dataset SINTÉTICO para probar el pipeline de punta a punta antes de tener datos reales.

Los resultados con estos datos NO dicen nada del modelo real: solo prueban que el código funciona.
Genera archivos con el mismo formato que tools/capture.

  python -m smartshoulder_ml.synthetic --out ../dataset_synth --subjects 8
"""
from __future__ import annotations

import argparse
import csv
from pathlib import Path

import numpy as np

from .preprocess import mirror_signs

FS = 50
SPEEDS = {"normal": 0.25, "lenta": 0.17, "rapida": 0.38}   # repeticiones por segundo

# Por ejercicio: eje de giro del dispositivo, amplitud angular (°), signo del primer movimiento, gravedad inicial.
EXERCISES = {
    1: dict(axis=1, amp=120, sign=1, g=(0, 0, -1)),        # flexión: gira en Y, inclinación grande
    2: dict(axis=0, amp=90, sign=1, g=(0, 0, -1)),         # abducción: gira en X
    3: dict(axis=2, amp=60, sign=1, g=(-1, 0, 0)),         # rotación externa: gira en Z, gravedad casi fija
    4: dict(axis=2, amp=60, sign=-1, g=(-1, 0, 0)),        # rotación interna: mismo arco, signo opuesto
    5: dict(axis=1, amp=70, sign=-1, g=(1, 0, 0)),         # tríceps: arco corto, antebrazo apuntando abajo
    6: dict(axis=0, amp=35, sign=1, g=(0, -1, 0), push=0.4),  # remo: poco giro + desplazamiento
}


def _rot(axis: int, a: float) -> np.ndarray:
    c, s = np.cos(a), np.sin(a)
    r = np.eye(3)
    i, j = [k for k in range(3) if k != axis]
    r[i, i], r[i, j], r[j, i], r[j, j] = c, -s, s, c
    return r


def _exercise(ex: int, speed: str, reps: int, rng: np.random.Generator, subj_amp: float) -> tuple[np.ndarray, list[int]]:
    p = EXERCISES[ex]
    f = SPEEDS[speed] * rng.uniform(0.9, 1.1)
    n = int(reps / f * FS)
    t = np.arange(n) / FS
    amp = np.deg2rad(p["amp"] * subj_amp * rng.uniform(0.9, 1.1))
    angle = p["sign"] * amp * (1 - np.cos(2 * np.pi * f * t)) / 2
    omega = np.gradient(angle, 1 / FS)
    gyro = np.zeros((n, 3))
    gyro[:, p["axis"]] = np.rad2deg(omega)
    g0 = np.array(p["g"], float)
    acc = np.stack([_rot(p["axis"], -a) @ g0 for a in angle])
    if "push" in p:
        acc[:, 0] += p["push"] * np.sin(2 * np.pi * f * t) * 0.3
    markers = [int((k + 1) / f * 1000) for k in range(reps)]
    return np.concatenate([acc, gyro], axis=1), markers


def _nulo(seconds: float, rng: np.random.Generator) -> np.ndarray:
    n = int(seconds * FS)
    out = np.zeros((n, 6))
    out[:, 2] = -1
    k = 0
    while k < n:
        kind = rng.choice(["rest", "walk", "gesture"], p=[0.5, 0.3, 0.2])
        m = min(n - k, int(rng.uniform(3, 15) * FS))
        t = np.arange(m) / FS
        if kind == "walk":
            out[k : k + m, 1 + 3] = 50 * np.sin(2 * np.pi * 0.9 * t)
            out[k : k + m, 0] = 0.2 * np.sin(2 * np.pi * 1.8 * t)
        elif kind == "gesture":
            axis = rng.integers(0, 3)
            out[k : k + m, 3 + axis] = 80 * np.exp(-((t - t.mean()) ** 2) / 0.3) * rng.choice([-1, 1])
        k += m
    return out


def generate(out: Path, subjects: int = 8, seed: int = 0) -> None:
    rng = np.random.default_rng(seed)
    (out / "raw").mkdir(parents=True, exist_ok=True)
    (out / "labels").mkdir(parents=True, exist_ok=True)
    subj_rows = []
    for s in range(1, subjects + 1):
        sid = f"S{s:02d}"
        arm = "L" if s % 4 == 0 else "R"
        subj_amp = rng.uniform(0.8, 1.2)
        mount = _rot(rng.integers(0, 3), np.deg2rad(rng.uniform(-8, 8)))
        chunks, labels, t0 = [], [], 0

        def add(x: np.ndarray, label=None):
            nonlocal t0
            if label:
                ex, sp, set_no, marks = label
                labels.append([t0, t0 + len(x) * 20, ex, set_no, sp, ";".join(str(t0 + m) for m in marks)])
            chunks.append(x)
            t0 += len(x) * 20

        add(_nulo(20, rng))
        for ex in range(1, 7):
            for set_no, sp in enumerate(SPEEDS, start=1):
                x, marks = _exercise(ex, sp, 10, rng, subj_amp)
                add(x, (ex, sp, set_no, marks))
                add(_nulo(rng.uniform(6, 12), rng))
        nulo = _nulo(180, rng)
        labels.append([t0, t0 + len(nulo) * 20, 0, 1, "natural", ""])
        add(nulo)

        x = np.concatenate(chunks)
        x = np.concatenate([x[:, :3] @ mount.T, x[:, 3:] @ mount.T], axis=1)
        x += rng.normal(0, 1, x.shape) * np.array([0.01, 0.01, 0.01, 1.5, 1.5, 1.5])
        if arm == "L":
            x *= mirror_signs()   # el espejado es su propia inversa: así "se ve" como brazo izquierdo
        name = f"{sid}_{arm}_2026-10-01"
        with open(out / "raw" / f"{name}.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["timestamp_ms", "ax", "ay", "az", "gx", "gy", "gz"])
            for i, row in enumerate(x):
                w.writerow([i * 20, *[f"{v:.5f}" for v in row]])
        with open(out / "labels" / f"{name}.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["start_ms", "end_ms", "exercise_id", "set", "speed", "rep_markers"])
            w.writerows(labels)
        subj_rows.append([sid, "F" if s % 2 else "M", 165, "R", arm])
    with open(out / "subjects.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["subject_id", "sex", "height_cm", "dominant_arm", "recorded_arm"])
        w.writerows(subj_rows)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Genera un dataset sintético para probar el pipeline")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--subjects", type=int, default=8)
    a = ap.parse_args()
    generate(a.out, a.subjects)
    print(f"Dataset sintético en {a.out} ({a.subjects} sujetos). Recuerda: solo sirve para probar el código.")
