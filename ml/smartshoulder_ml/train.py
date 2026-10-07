"""Evaluar y exportar.

  python -m smartshoulder_ml.train --data ../dataset --model baseline           # rápido: ¿el problema es fácil?
  python -m smartshoulder_ml.train --data ../dataset --model cnn --epochs 30    # candidato principal (LOSO)
  python -m smartshoulder_ml.train --data ../dataset --model cnn --export 1 --to-firmware
"""
from __future__ import annotations

import argparse
import os
import shutil
import time
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")

from .config import STEP_TRAIN, TARGET_COUNT_WITHIN_1, TARGET_F1_MACRO, TARGET_NULO_FALSE_POSITIVE
from .data import dataset_hash, load_dataset
from .pipeline import evaluate_counter, fit_cnn, loso
from .windows import windows_from

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, default=ROOT / "dataset")
    ap.add_argument("--model", choices=["baseline", "cnn"], default="cnn")
    ap.add_argument("--epochs", type=int, default=30)
    ap.add_argument("--folds", type=int, default=None, help="limitar LOSO a N sujetos (pruebas rápidas)")
    ap.add_argument("--skip-loso", action="store_true")
    ap.add_argument("--export", type=int, metavar="VERSION", help="entrenar con todos los sujetos y exportar model_vN")
    ap.add_argument("--to-firmware", action="store_true", help="copiar model_data.h y model_config.h al firmware")
    a = ap.parse_args()

    recs = load_dataset(a.data)
    subjects = sorted({r.subject for r in recs})
    print(f"Dataset {a.data}: {len(recs)} grabaciones, {len(subjects)} sujetos, {sum(r.duration_s for r in recs) / 60:.0f} min")

    metrics: dict = {}
    if not a.skip_loso:
        t = time.time()
        res = loso(recs, a.model, a.epochs, a.folds)
        print(res.report())
        print(f"  ({time.time() - t:.0f} s)")
        ok = res.f1_macro >= TARGET_F1_MACRO and res.nulo_false_positive < TARGET_NULO_FALSE_POSITIVE
        print(f"  Meta Demo Day: F1 ≥ {TARGET_F1_MACRO} y NULO < {TARGET_NULO_FALSE_POSITIVE:.0%} → {'CUMPLE' if ok else 'NO CUMPLE'}")
        metrics = {
            "loso_f1_macro": round(res.f1_macro, 4),
            "loso_accuracy": round(res.accuracy, 4),
            "loso_nulo_false_positive": round(res.nulo_false_positive, 4),
            "loso_per_subject_f1": {k: round(v, 4) for k, v in res.per_subject.items()},
            "loso_confusion": res.confusion().tolist(),
        }

    cnt = evaluate_counter(recs)
    print(cnt.report())
    within1 = float((abs(cnt.errors) <= 1).mean()) if len(cnt.errors) else 0.0
    print(f"  Meta Demo Day: ±1 rep en ≥ {TARGET_COUNT_WITHIN_1:.0%} de las series → {'CUMPLE' if within1 >= TARGET_COUNT_WITHIN_1 else 'NO CUMPLE'}")
    metrics["count_within_1"] = round(within1, 4)

    if a.export is not None:
        if a.model != "cnn":
            raise SystemExit("Solo se exporta la CNN (la línea base no corre en el dispositivo).")
        from .export import export

        print(f"Entrenando model_v{a.export} con todos los sujetos…")
        train = windows_from(recs, STEP_TRAIN)
        trained = fit_cnn(train, epochs=a.epochs)
        out = ROOT / "ml" / "models" / f"model_v{a.export}"
        card = export(trained, train, out, a.export, {"dataset": str(a.data), "dataset_hash": dataset_hash(a.data), "subjects": subjects, **metrics})
        print(f"Exportado en {out}: {card['tflite_bytes'] / 1024:.1f} KB, {card['params']} parámetros, "
              f"int8 = float en {card['int8_agreement_with_float']:.1%} de las ventanas")
        print(f"  Ops para el firmware: {', '.join(card['ops'])}")
        if a.to_firmware:
            fw = ROOT / "firmware" / "smartshoulder"
            for f in ("model_data.h", "model_config.h"):
                shutil.copy(out / f, fw / f)
            print(f"  Copiado a {fw}")


if __name__ == "__main__":
    main()
