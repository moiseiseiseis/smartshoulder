"""Simula el firmware v2 completo sobre grabaciones: modelo int8 + contador + regla de verificación.

  python -m rumbo_ml.verify --model 1                # cada serie con su ejercicio real como esperado
  python -m rumbo_ml.verify --model 1 --wrong        # además, cada serie con OTRO ejercicio esperado (debe rechazar)

Misma lógica que firmware/rumbo/rumbo.ino (inferenceTick / repMatchesExpected) y classifier.cpp.
Si el modelo se entrenó con estas mismas grabaciones, el resultado es optimista: prueba la lógica, no la generalización.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")

import numpy as np

from .config import CLASS_MERGE, CLASSES, N_CLASSES, STEP_INFERENCE, WINDOW
from .data import Recording, contiguous_runs, load_dataset
from .export import Int8Model
from .preprocess import Normalizer, mirror
from .repcounter import RepCounter, params_for

ROOT = Path(__file__).resolve().parents[2]


def class_of(exercise_id: int) -> int:
    return CLASS_MERGE.get(exercise_id, exercise_id)


def predictions(rec: Recording, model: Int8Model, norm: Normalizer) -> dict[int, int]:
    """Índice de muestra → clase predicha, para cada muestra en la que el firmware corre el modelo."""
    x = norm(mirror(rec.x, rec.arm))
    out: dict[int, int] = {}
    for i0, i1 in contiguous_runs(rec.t_ms):   # el firmware reinicia la ventana si hay hueco (aprox.)
        ends = list(range(i0 + WINDOW - 1, i1, STEP_INFERENCE))
        if not ends:
            continue
        p = model.predict_proba(np.stack([x[e - WINDOW + 1 : e + 1] for e in ends])).argmax(1)
        out.update(zip(ends, p.tolist()))
    return out


def run_set(rec: Recording, start: int, end: int, expected: int, preds: dict[int, int]) -> tuple[int, int]:
    """(aceptadas, rechazadas) en una serie con `expected` como ejercicio esperado."""
    rc = RepCounter(params_for(expected))
    votes = np.zeros(N_CLASSES, int)
    target = class_of(expected)
    acc = rej = 0
    for i in range(start, end):
        if i in preds:
            votes[preds[i]] += 1
        if not rc.update(rec.x[i]):
            continue
        other = max(votes[k] for k in range(1, N_CLASSES) if k != target)
        if votes[target] > 0 and votes[target] >= other:
            acc += 1
        else:
            rej += 1
        votes[:] = 0
    return acc, rej


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, default=ROOT / "dataset")
    ap.add_argument("--model", type=int, required=True)
    ap.add_argument("--wrong", action="store_true")
    a = ap.parse_args()

    import json

    mdir = ROOT / "ml" / "models" / f"model_v{a.model}"
    card = json.loads((mdir / "model_card.json").read_text(encoding="utf-8"))
    n = card["normalization"]
    norm = Normalizer(np.array(list(n["mean"].values()), np.float32), np.array(list(n["std"].values()), np.float32))
    model = Int8Model((mdir / "model.tflite").read_bytes())

    right, wrong = [], []
    for rec in load_dataset(a.data):
        preds = predictions(rec, model, norm)
        for s in rec.sets:
            if not s.exercise_id:
                continue
            idx = np.where((rec.t_ms >= s.start_ms) & (rec.t_ms < s.end_ms + 600))[0]
            i0, i1 = int(idx[0]), int(idx[-1]) + 1
            truth = len(s.rep_markers) or 10
            ok, rej = run_set(rec, i0, i1, s.exercise_id, preds)
            right.append((rec.name, s.exercise_id, s.speed, truth, ok, rej))
            if a.wrong:
                for other in CLASSES:
                    if other and class_of(other) != class_of(s.exercise_id):
                        wrong.append((s.exercise_id, other, *run_set(rec, i0, i1, other, preds)))

    print(f"Modelo v{a.model} · ejercicio correcto ({len(right)} series)")
    errs = np.array([ok - t for *_, t, ok, _ in right])
    print(f"  error medio {np.abs(errs).mean():.2f} reps · exacto {np.mean(errs == 0):.0%} · ±1 {np.mean(np.abs(errs) <= 1):.0%}")
    for ex in sorted({r[1] for r in right}):
        rows = [r for r in right if r[1] == ex]
        e = np.array([ok - t for *_, t, ok, _ in rows])
        print(f"  {ex} {CLASSES[ex]:<26} contadas {'/'.join(str(r[4]) for r in rows):<14} real {'/'.join(str(r[3]) for r in rows):<10}"
              f" rechazadas {sum(r[5] for r in rows):>2} · error medio {np.abs(e).mean():.1f}")
    if wrong:
        total = sum(acc + rej for *_, acc, rej in wrong)
        leaked = sum(acc for *_, acc, _ in wrong)
        print(f"Ejercicio equivocado ({len(wrong)} combinaciones): {leaked} de {total} repeticiones aceptadas por error ({leaked / max(total, 1):.1%})")
        worst: dict[tuple[int, int], int] = {}
        for real, exp, acc, _ in wrong:
            worst[(real, exp)] = worst.get((real, exp), 0) + acc
        for (real, exp), v in sorted(worst.items(), key=lambda kv: -kv[1])[:5]:
            if v:
                print(f"  hace {CLASSES[real]} con {CLASSES[exp]} esperado: {v} aceptadas")


if __name__ == "__main__":
    main()
