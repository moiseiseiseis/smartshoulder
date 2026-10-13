"""Carga del dataset con el formato de tools/capture (contexto/05 §3.5).

dataset/
  raw/S01_R_2026-10-08.csv      timestamp_ms, ax, ay, az, gx, gy, gz   (g, dps)
  labels/S01_R_2026-10-08.csv   start_ms, end_ms, exercise_id, set, speed, rep_markers
  subjects.csv                  subject_id, sex, height_cm, dominant_arm, recorded_arm
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd

from .config import CHANNELS, SAMPLE_MS


@dataclass
class SetLabel:
    start_ms: int
    end_ms: int
    exercise_id: int
    set: int
    speed: str
    rep_markers: list[int] = field(default_factory=list)


@dataclass
class Recording:
    name: str                 # nombre del archivo, p. ej. S01_R_2026-10-08
    subject: str
    arm: str                  # "R" / "L"
    t_ms: np.ndarray          # (n,) int64
    x: np.ndarray             # (n, 6) float32, unidades físicas
    sets: list[SetLabel]

    @property
    def duration_s(self) -> float:
        return float(self.t_ms[-1] - self.t_ms[0]) / 1000 if len(self.t_ms) else 0.0

    def sample_labels(self) -> np.ndarray:
        """Etiqueta por muestra: exercise_id dentro de una serie, 0 (NULO) fuera."""
        y = np.zeros(len(self.t_ms), dtype=np.int64)
        for s in self.sets:
            y[(self.t_ms >= s.start_ms) & (self.t_ms < s.end_ms)] = s.exercise_id
        return y

    def segment(self, s: SetLabel) -> np.ndarray:
        m = (self.t_ms >= s.start_ms) & (self.t_ms < s.end_ms)
        return self.x[m]


def _parse_markers(v) -> list[int]:
    if v is None or (isinstance(v, float) and np.isnan(v)) or str(v).strip() == "":
        return []
    return [int(float(t)) for t in str(v).split(";") if t.strip()]


def load_recording(raw_path: Path) -> Recording:
    raw_path = Path(raw_path)
    df = pd.read_csv(raw_path)
    missing = [c for c in ["timestamp_ms", *CHANNELS] if c not in df.columns]
    if missing:
        raise ValueError(f"{raw_path.name}: faltan columnas {missing}")
    df = df.sort_values("timestamp_ms").drop_duplicates("timestamp_ms")
    labels_path = raw_path.parent.parent / "labels" / raw_path.name
    sets: list[SetLabel] = []
    if labels_path.exists():
        lab = pd.read_csv(labels_path)
        for r in lab.itertuples(index=False):
            if pd.isna(r.end_ms):
                continue
            sets.append(SetLabel(int(r.start_ms), int(r.end_ms), int(r.exercise_id), int(r.set), str(r.speed), _parse_markers(r.rep_markers)))
    parts = raw_path.stem.split("_")
    return Recording(
        name=raw_path.stem,
        subject=parts[0],
        arm=parts[1] if len(parts) > 1 else "R",
        t_ms=df["timestamp_ms"].to_numpy(np.int64),
        x=df[CHANNELS].to_numpy(np.float32),
        sets=sets,
    )


def load_dataset(root: Path) -> list[Recording]:
    raw = sorted((Path(root) / "raw").glob("*.csv"))
    if not raw:
        raise FileNotFoundError(f"No hay grabaciones en {Path(root) / 'raw'}")
    return [load_recording(p) for p in raw]


def contiguous_runs(t_ms: np.ndarray) -> list[tuple[int, int]]:
    """Tramos [i, j) sin huecos (muestras consecutivas a 20 ms). Las ventanas nunca cruzan un hueco."""
    if len(t_ms) == 0:
        return []
    breaks = np.where(np.diff(t_ms) != SAMPLE_MS)[0] + 1
    edges = [0, *breaks.tolist(), len(t_ms)]
    return [(edges[k], edges[k + 1]) for k in range(len(edges) - 1)]


def dataset_hash(root: Path) -> str:
    """Huella del dataset (crudos + etiquetas) para la ficha del modelo (contexto/03 §8)."""
    h = hashlib.sha256()
    for p in sorted(Path(root).glob("*/*.csv")) + sorted(Path(root).glob("*.csv")):
        h.update(p.relative_to(root).as_posix().encode())
        h.update(p.read_bytes())
    return h.hexdigest()[:16]
