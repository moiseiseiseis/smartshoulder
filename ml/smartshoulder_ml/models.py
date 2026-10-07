"""Arquitecturas candidatas (contexto/03 §4). Se prueba en orden y se queda la más simple que cumpla las metas."""
from __future__ import annotations

import os

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")

import numpy as np
from sklearn.ensemble import RandomForestClassifier

from .config import N_CLASSES, WINDOW
from .features import window_features


# ----------------------------------------------------------------- A: línea base
class Baseline:
    """Características estadísticas + Random Forest. Rápido; dice si el problema es fácil. No se exporta."""

    def __init__(self, seed: int = 0):
        self.clf = RandomForestClassifier(n_estimators=200, min_samples_leaf=2, class_weight="balanced", n_jobs=-1, random_state=seed)

    def fit(self, x: np.ndarray, y: np.ndarray) -> "Baseline":
        self.clf.fit(window_features(x), y)
        return self

    def predict(self, x: np.ndarray) -> np.ndarray:
        return self.clf.predict(window_features(x))


# ----------------------------------------------------------------- B: 1D-CNN pequeña
def build_cnn(filters=(16, 32, 32), kernel=5, dense=32, dropout=0.2, batch_size=None):
    """1D-CNN como Conv2D de alto 1 (contexto/03 §4: TFLite Micro implementa Conv1D así).

    Solo usa operaciones soportadas por TFLM con int8: RESHAPE, CONV_2D, MAX_POOL_2D, MEAN, FULLY_CONNECTED, SOFTMAX.
    Para exportar se construye con batch_size=1: con lote dinámico el Reshape agrega SHAPE/PACK/STRIDED_SLICE.
    """
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras import layers

    inp = keras.Input(shape=(WINDOW, 6), batch_size=batch_size, name="imu")
    h = layers.Reshape((1, WINDOW, 6))(inp)
    for i, f in enumerate(filters):
        h = layers.Conv2D(f, (1, kernel), padding="same", activation="relu", name=f"conv{i}")(h)
        if i < len(filters) - 1:
            h = layers.MaxPooling2D((1, 2), name=f"pool{i}")(h)
    h = layers.GlobalAveragePooling2D(name="gap")(h)
    h = layers.Dropout(dropout)(h)
    h = layers.Dense(dense, activation="relu", name="fc")(h)
    out = layers.Dense(N_CLASSES, activation="softmax", name="probs")(h)
    model = keras.Model(inp, out, name="smartshoulder_cnn")
    model.compile(optimizer=keras.optimizers.Adam(2e-3), loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    tf.keras.utils.set_random_seed(0)
    return model


def class_weights(y: np.ndarray) -> dict[int, float]:
    counts = np.bincount(y, minlength=N_CLASSES).astype(np.float64)
    w = counts.sum() / (N_CLASSES * np.maximum(counts, 1))
    return {i: float(w[i]) for i in range(N_CLASSES) if counts[i] > 0}
