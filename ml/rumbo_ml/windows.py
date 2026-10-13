"""Ventaneo con la regla de etiquetado de contexto/03 §3.3."""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .config import AMBIGUOUS_MAX_FRACTION, LABEL_MIN_FRACTION, WINDOW
from .data import Recording, contiguous_runs
from .preprocess import mirror


@dataclass
class Windows:
    x: np.ndarray          # (n, WINDOW, 6) float32, físico y ya espejado
    y: np.ndarray          # (n,) clase
    subject: np.ndarray    # (n,) str
    recording: np.ndarray  # (n,) str

    def __len__(self) -> int:
        return len(self.y)

    def take(self, mask: np.ndarray) -> "Windows":
        return Windows(self.x[mask], self.y[mask], self.subject[mask], self.recording[mask])

    @staticmethod
    def concat(parts: list["Windows"]) -> "Windows":
        parts = [p for p in parts if len(p)]
        if not parts:
            return Windows(np.zeros((0, WINDOW, 6), np.float32), np.zeros(0, np.int64), np.zeros(0, str), np.zeros(0, str))
        return Windows(*(np.concatenate([getattr(p, f) for p in parts]) for f in ("x", "y", "subject", "recording")))


def label_window(labels: np.ndarray) -> int | None:
    """Clase de la ventana: ejercicio si ≥ 80 % de sus muestras son de una serie; NULO si ≤ 20 %; None si es ambigua."""
    nz = labels[labels > 0]
    frac = len(nz) / len(labels)
    if frac >= LABEL_MIN_FRACTION:
        values, counts = np.unique(nz, return_counts=True)
        top = values[np.argmax(counts)]
        return int(top) if counts.max() / len(labels) >= LABEL_MIN_FRACTION else None
    if frac <= AMBIGUOUS_MAX_FRACTION:
        return 0
    return None


def make_windows(rec: Recording, step: int, keep_ambiguous: bool = False) -> Windows:
    x = mirror(rec.x, rec.arm)
    lab = rec.sample_labels()
    xs, ys = [], []
    for i0, i1 in contiguous_runs(rec.t_ms):
        for s in range(i0, i1 - WINDOW + 1, step):
            y = label_window(lab[s : s + WINDOW])
            if y is None and not keep_ambiguous:
                continue
            xs.append(x[s : s + WINDOW])
            ys.append(-1 if y is None else y)
    n = len(ys)
    return Windows(
        np.asarray(xs, np.float32).reshape(n, WINDOW, 6),
        np.asarray(ys, np.int64),
        np.full(n, rec.subject),
        np.full(n, rec.name),
    )


def windows_from(recordings: list[Recording], step: int) -> Windows:
    return Windows.concat([make_windows(r, step) for r in recordings])
