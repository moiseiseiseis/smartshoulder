"""Control de calidad después de cada participante (contexto/05 §3.4).

  python -m smartshoulder_ml.qc                     # todo el dataset
  python -m smartshoulder_ml.qc --subject S03 --plots

Revisa: frecuencia real, huecos, saturación, cobertura del protocolo (6 ejercicios × 3 ritmos + NULO ≥ 3 min),
marcas de repetición contra las del protocolo y cuántas cuenta el contador del firmware.
Con --plots guarda una figura por serie en dataset/qc/ para revisar a ojo.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from .config import ACCEL_RANGE_G, CLASSES, GYRO_RANGE_DPS, SAMPLE_MS
from .data import Recording, load_dataset, load_recording
from .preprocess import mirror
from .pipeline import COUNT_PAD_MS
from .repcounter import count_reps

ROOT = Path(__file__).resolve().parents[2]
SPEEDS = ("normal", "lenta", "rapida")


def check(rec: Recording) -> list[str]:
    """Problemas encontrados (vacío = todo bien) + resumen impreso."""
    issues: list[str] = []
    dt = np.diff(rec.t_ms)
    lost = int(((dt[dt > SAMPLE_MS] // SAMPLE_MS) - 1).sum()) if len(dt) else 0
    sat_acc = float((np.abs(rec.x[:, :3]) > ACCEL_RANGE_G * 0.98).mean())
    sat_gyr = float((np.abs(rec.x[:, 3:]) > GYRO_RANGE_DPS * 0.98).mean())
    print(f"\n{rec.name}: {rec.duration_s / 60:.1f} min · {len(rec.t_ms)} muestras · perdidas {lost} · "
          f"saturación acc {sat_acc:.2%} giro {sat_gyr:.2%} · {len(rec.sets)} series")
    if lost > len(rec.t_ms) * 0.005:
        issues.append(f"{lost} muestras perdidas (> 0.5 %)")
    if sat_acc > 0.001 or sat_gyr > 0.001:
        issues.append("hay saturación: movimientos demasiado bruscos o rango insuficiente")

    x = mirror(rec.x, rec.arm)
    done = set()
    nulo_s = 0.0
    for s in rec.sets:
        dur = (s.end_ms - s.start_ms) / 1000
        if s.exercise_id == 0:
            nulo_s += dur
            continue
        done.add((s.exercise_id, s.speed))
        seg = x[(rec.t_ms >= s.start_ms) & (rec.t_ms < s.end_ms + COUNT_PAD_MS)]
        counted = count_reps(seg)
        marks = len(s.rep_markers)
        amp = float(np.abs(seg[:, 3:]).max()) if len(seg) else 0.0
        flag = ""
        if dur < 8:
            flag += "  ⚠ serie muy corta"
        if amp < 40:
            flag += "  ⚠ casi sin movimiento"
        if marks and abs(marks - 10) > 1:
            flag += f"  ⚠ {marks} marcas (protocolo: 10)"
        if abs(counted - (marks or 10)) > 1:
            flag += "  ⚠ el contador no coincide"
        print(f"  {s.exercise_id} {CLASSES[s.exercise_id][:22]:<22} {s.speed:<7} serie {s.set} · {dur:5.1f} s · "
              f"giro máx {amp:4.0f} dps · marcas {marks:2d} · contador {counted:2d}{flag}")
        if "⚠" in flag:
            issues.append(f"{CLASSES[s.exercise_id]} {s.speed}: {flag.strip()}")

    missing = [f"{CLASSES[e]} {sp}" for e in range(1, 7) for sp in SPEEDS if (e, sp) not in done]
    print(f"  NULO etiquetado: {nulo_s / 60:.1f} min")
    if missing:
        issues.append("faltan: " + ", ".join(missing))
    if nulo_s < 180:
        issues.append(f"NULO de {nulo_s / 60:.1f} min (meta ≥ 3 min)")
    return issues


def plots(rec: Recording, out: Path) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    out.mkdir(parents=True, exist_ok=True)
    for s in rec.sets:
        m = (rec.t_ms >= s.start_ms - 2000) & (rec.t_ms < s.end_ms + 2000)
        t = (rec.t_ms[m] - s.start_ms) / 1000
        fig, (a1, a2) = plt.subplots(2, 1, figsize=(11, 5), sharex=True)
        for i, c in enumerate("xyz"):
            a1.plot(t, rec.x[m, i], lw=0.8, label=f"a{c}")
            a2.plot(t, rec.x[m, 3 + i], lw=0.8, label=f"g{c}")
        for a in (a1, a2):
            a.axvspan(0, (s.end_ms - s.start_ms) / 1000, color="tab:red", alpha=0.07)
            for mk in s.rep_markers:
                a.axvline((mk - s.start_ms) / 1000, color="k", lw=0.5, alpha=0.4)
            a.legend(loc="upper right", fontsize=7)
            a.grid(alpha=0.3)
        a1.set_ylabel("g")
        a2.set_ylabel("dps")
        a2.set_xlabel("s")
        fig.suptitle(f"{rec.name} · {CLASSES[s.exercise_id]} · {s.speed} · serie {s.set}")
        fig.tight_layout()
        fig.savefig(out / f"{rec.name}_{s.exercise_id}_{s.speed}_{s.set}.png", dpi=80)
        plt.close(fig)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, default=ROOT / "dataset")
    ap.add_argument("--subject")
    ap.add_argument("--plots", action="store_true")
    a = ap.parse_args()
    recs = [load_recording(p) for p in sorted((a.data / "raw").glob(f"{a.subject}_*.csv"))] if a.subject else load_dataset(a.data)
    total = 0
    for r in recs:
        issues = check(r)
        total += len(issues)
        print("  ✓ Sin problemas" if not issues else "  Revisar:\n    - " + "\n    - ".join(issues))
        if a.plots:
            plots(r, a.data / "qc")
    if a.plots:
        print(f"\nFiguras en {a.data / 'qc'}")
    print(f"\n{len(recs)} grabaciones · {total} puntos a revisar")


if __name__ == "__main__":
    main()
