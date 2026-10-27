"""Calibra los umbrales del contador POR EJERCICIO con el dataset (contexto/03 §6, punto 5).

  python -m rumbo_ml.calibrate            # busca en una rejilla y muestra la tabla para repcounter.cpp

El reloj sabe qué ejercicio toca (SET_EXPECTED), así que puede usar umbrales distintos para cada uno:
la estabilización escapular gira mucho menos que una flexión. Real = marcas de repetición o 10 por serie.
"""
from __future__ import annotations

import argparse
import itertools
from pathlib import Path

import numpy as np

from .config import CLASSES
from .data import load_dataset
from .pipeline import COUNT_PAD_MS
from .repcounter import FIRMWARE_PARAMS, RepParams, count_reps

ROOT = Path(__file__).resolve().parents[2]

T_HIGH = [4, 6, 8, 10, 12, 15, 20, 25, 30, 40]   # dps (giro) o cg (acel)
LOW_RATIO = [0.3, 0.4, 0.5, 0.6]
MIN_REP = [25, 40, 60, 80]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, default=ROOT / "dataset")
    a = ap.parse_args()

    sets: dict[int, list[tuple[np.ndarray, int]]] = {}
    for r in load_dataset(a.data):
        for s in r.sets:
            if s.exercise_id:
                seg = r.x[(r.t_ms >= s.start_ms) & (r.t_ms < s.end_ms + COUNT_PAD_MS)]
                sets.setdefault(s.exercise_id, []).append((seg, len(s.rep_markers) or 10))

    print("Error medio por serie (actual → calibrado). Copiar la tabla a firmware/rumbo/repcounter.cpp y repcounter.py:\n")
    table = {}
    for ex, items in sorted(sets.items()):
        def score(p: RepParams) -> tuple[float, float]:
            e = np.array([count_reps(x, p) - t for x, t in items])
            return float(np.abs(e).mean()), float(np.abs(e).max())

        best, best_s = FIRMWARE_PARAMS, score(FIRMWARE_PARAMS)
        before = best_s
        for acc, th, lr, mr in itertools.product([False, True], T_HIGH, LOW_RATIO, MIN_REP):
            p = RepParams(t_high=th, t_low=round(th * lr, 1), min_rep=mr, accel=acc)
            s = score(p)
            # Desempate hacia umbrales más altos (más robustos al ruido de reposo).
            if s < best_s or (s == best_s and not p.accel and p.t_high > best.t_high):
                best, best_s = p, s
        table[ex] = best
        counts = [count_reps(x, best) for x, _ in items]
        print(f"  {ex} {CLASSES[ex]:<26} {before[0]:.2f} → {best_s[0]:.2f} (máx {best_s[1]:.0f})  "
              f"{'acel' if best.accel else 'giro'} T_HIGH {best.t_high:>4} T_LOW {best.t_low:>4} MIN_REP {best.min_rep:>3}   contadas {counts}")

    print("\n# repcounter.py → EXERCISE_PARAMS")
    for ex, p in table.items():
        print(f"    {ex}: RepParams(t_high={p.t_high:.1f}, t_low={p.t_low:.1f}, min_rep={p.min_rep}, accel={p.accel}),   # {CLASSES[ex]}")
    print("\n// repcounter.cpp → EXERCISE_PARAMS: {accel, T_HIGH, T_LOW, MIN_REP}")
    for ex, p in table.items():
        print(f"  {{{str(p.accel).lower()}, {p.t_high:.1f}f, {p.t_low:.1f}f, {p.min_rep}}},   // {ex} {CLASSES[ex]}")


if __name__ == "__main__":
    main()
