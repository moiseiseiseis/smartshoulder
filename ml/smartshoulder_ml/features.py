"""Características por ventana para la línea base A (contexto/03 §4): media, desviación, mín, máx, energía."""
import numpy as np


def window_features(x: np.ndarray) -> np.ndarray:
    """x: (n, WINDOW, 6) → (n, 30)."""
    return np.concatenate(
        [x.mean(axis=1), x.std(axis=1), x.min(axis=1), x.max(axis=1), (x**2).mean(axis=1)],
        axis=1,
    ).astype(np.float32)
