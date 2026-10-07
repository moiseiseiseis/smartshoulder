"""Aumento de datos, solo para entrenar (contexto/03 §3.4). Opera en unidades físicas, antes de normalizar."""
from __future__ import annotations

import numpy as np

from .config import WINDOW


def _rotation(rng: np.random.Generator, max_deg: float) -> np.ndarray:
    """Rotación pequeña aleatoria: simula el reloj un poco girado en la muñeca."""
    axis = rng.normal(size=3)
    axis /= np.linalg.norm(axis)
    a = np.deg2rad(rng.uniform(-max_deg, max_deg))
    k = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    return (np.eye(3) + np.sin(a) * k + (1 - np.cos(a)) * k @ k).astype(np.float32)


def _stretch(w: np.ndarray, factor: float) -> np.ndarray:
    """Estira o comprime en el tiempo (gente lenta o rápida) y recorta/rellena a WINDOW."""
    n = len(w)
    src = np.linspace(0, n - 1, max(2, int(round(n * factor))))
    out = np.stack([np.interp(src, np.arange(n), w[:, c]) for c in range(6)], axis=1)
    if len(out) >= WINDOW:
        start = (len(out) - WINDOW) // 2
        return out[start : start + WINDOW]
    pad = WINDOW - len(out)
    return np.pad(out, ((pad // 2, pad - pad // 2), (0, 0)), mode="edge")


def augment(x: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """x: (n, WINDOW, 6) físico → copia aumentada."""
    out = np.empty_like(x)
    for i, w in enumerate(x):
        w = _stretch(w, rng.uniform(0.85, 1.15))
        r = _rotation(rng, 10)
        w = np.concatenate([w[:, :3] @ r.T, w[:, 3:] @ r.T], axis=1)
        w = w * rng.uniform(0.9, 1.1)
        w = w + rng.normal(0, 1, w.shape) * np.array([0.01, 0.01, 0.01, 2, 2, 2])
        out[i] = w
    return out.astype(np.float32)
