"""Preprocesamiento. DEBE ser idéntico en el firmware (preprocess.cpp): cualquier diferencia rompe el modelo en silencio.

Orden (contexto/03 §3.2):
  1. unidades físicas (g, dps) — ya vienen así del CSV; en el firmware: crudo × escala
  2. espejado si el brazo es el izquierdo
  3. z-score por canal con media/desviación del set de entrenamiento (congeladas en model_config.h)
  4. cuantización a int8 con la escala/zero-point del modelo exportado
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .config import CHANNELS, MIRROR_AXIS

AXES = "xyz"


def mirror_signs(axis: str = MIRROR_AXIS) -> np.ndarray:
    """Signos por canal (ax..gz) para llevar una muestra del brazo izquierdo al derecho."""
    k = AXES.index(axis)
    acc = np.ones(3, np.float32)
    acc[k] = -1                       # componente perpendicular al plano de reflexión
    gyr = -np.ones(3, np.float32)
    gyr[k] = 1                        # pseudovector: se invierten las paralelas al plano
    return np.concatenate([acc, gyr])


def mirror(x: np.ndarray, arm: str, axis: str = MIRROR_AXIS) -> np.ndarray:
    return x * mirror_signs(axis) if arm == "L" else x


@dataclass
class Normalizer:
    mean: np.ndarray   # (6,)
    std: np.ndarray    # (6,)

    @classmethod
    def fit(cls, x: np.ndarray) -> "Normalizer":
        flat = x.reshape(-1, x.shape[-1]).astype(np.float64)
        std = flat.std(axis=0)
        std[std < 1e-6] = 1.0
        return cls(flat.mean(axis=0).astype(np.float32), std.astype(np.float32))

    def __call__(self, x: np.ndarray) -> np.ndarray:
        return ((x - self.mean) / self.std).astype(np.float32)

    def to_dict(self) -> dict:
        return {"mean": dict(zip(CHANNELS, self.mean.tolist())), "std": dict(zip(CHANNELS, self.std.tolist()))}


def estimate_mirror_axis(right: np.ndarray, left: np.ndarray) -> dict[str, float]:
    """Compara el MISMO ejercicio grabado con cada brazo y puntúa cada eje candidato de espejado.

    right, left: segmentos (n, 6) en unidades físicas. Devuelve {eje: distancia}; el menor es el bueno.
    Se compara la media y la correlación de signo de cada canal (robusto a diferencias de ritmo).
    """
    def profile(x: np.ndarray) -> np.ndarray:
        mean = x.mean(axis=0)  # la gravedad (media del acelerómetro) distingue el eje reflejado
        # correlación de cada canal de giro con el canal de giro dominante: captura el signo relativo
        g = x[:, 3:]
        dom = np.argmax(g.std(axis=0))
        corr = np.array([np.corrcoef(g[:, dom], g[:, i])[0, 1] if g[:, i].std() > 1e-6 else 0 for i in range(3)])
        return np.concatenate([mean / (np.abs(mean).max() + 1e-6), corr])

    ref = profile(right)
    return {ax: float(np.linalg.norm(profile(left * mirror_signs(ax)) - ref)) for ax in AXES}
