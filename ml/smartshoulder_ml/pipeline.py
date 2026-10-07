"""Entrenamiento y evaluación leave-one-subject-out (contexto/03 §5)."""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score

from .augment import augment
from .config import CLASSES, N_CLASSES, STEP_INFERENCE, STEP_TRAIN
from .data import Recording
from .models import Baseline, build_cnn, class_weights
from .preprocess import Normalizer, mirror
from .repcounter import RepParams, count_reps, FIRMWARE_PARAMS
from .windows import Windows, windows_from


@dataclass
class TrainedCnn:
    model: object
    normalizer: Normalizer

    def predict_proba(self, x: np.ndarray) -> np.ndarray:
        return self.model.predict(self.normalizer(x), verbose=0, batch_size=512)

    def predict(self, x: np.ndarray) -> np.ndarray:
        return self.predict_proba(x).argmax(axis=1)


def fit_cnn(train: Windows, epochs: int = 30, seed: int = 0, augment_copies: int = 1, verbose: int = 0) -> TrainedCnn:
    import tensorflow as tf

    rng = np.random.default_rng(seed)
    norm = Normalizer.fit(train.x)   # solo con datos reales de entrenamiento, sin aumentar
    xs = [train.x] + [augment(train.x, rng) for _ in range(augment_copies)]
    x = norm(np.concatenate(xs))
    y = np.concatenate([train.y] * (1 + augment_copies))
    model = build_cnn()
    model.fit(
        x,
        y,
        epochs=epochs,
        batch_size=64,
        shuffle=True,
        class_weight=class_weights(y),
        verbose=verbose,
        callbacks=[tf.keras.callbacks.ReduceLROnPlateau(monitor="loss", factor=0.5, patience=4, min_lr=1e-4)],
    )
    return TrainedCnn(model, norm)


@dataclass
class LosoResult:
    kind: str
    y_true: np.ndarray
    y_pred: np.ndarray
    per_subject: dict[str, float] = field(default_factory=dict)

    @property
    def accuracy(self) -> float:
        return float(accuracy_score(self.y_true, self.y_pred))

    @property
    def f1_macro(self) -> float:
        labels = sorted(set(self.y_true.tolist()))
        return float(f1_score(self.y_true, self.y_pred, labels=labels, average="macro", zero_division=0))

    @property
    def nulo_false_positive(self) -> float:
        """Fracción de ventanas NULO que el modelo confunde con un ejercicio (meta < 5 %)."""
        m = self.y_true == 0
        return float((self.y_pred[m] != 0).mean()) if m.any() else float("nan")

    def confusion(self) -> np.ndarray:
        return confusion_matrix(self.y_true, self.y_pred, labels=list(range(N_CLASSES)))

    def report(self) -> str:
        lines = [
            f"Modelo {self.kind} · LOSO ({len(self.per_subject)} sujetos, {len(self.y_true)} ventanas de prueba)",
            f"  accuracy {self.accuracy:.3f}   F1 macro {self.f1_macro:.3f}   NULO→ejercicio {self.nulo_false_positive:.1%}",
            "  F1 por sujeto: " + "  ".join(f"{s} {v:.2f}" for s, v in sorted(self.per_subject.items())),
            "  Matriz de confusión (filas = real, columnas = predicho):",
            "        " + " ".join(f"{i:>6}" for i in range(N_CLASSES)),
        ]
        for i, row in enumerate(self.confusion()):
            lines.append(f"  {i} {CLASSES[i][:5]:<5}" + " ".join(f"{v:>6}" for v in row))
        return "\n".join(lines)


def loso(recordings: list[Recording], kind: str = "cnn", epochs: int = 30, max_folds: int | None = None, log=print) -> LosoResult:
    subjects = sorted({r.subject for r in recordings})
    if len(subjects) < 2:
        raise ValueError("LOSO necesita al menos 2 sujetos")
    folds = subjects[:max_folds] if max_folds else subjects
    trues, preds, per_subject = [], [], {}
    for s in folds:
        train = windows_from([r for r in recordings if r.subject != s], STEP_TRAIN)
        test = windows_from([r for r in recordings if r.subject == s], STEP_INFERENCE)
        if not len(test):
            continue
        model = Baseline().fit(train.x, train.y) if kind == "baseline" else fit_cnn(train, epochs=epochs)
        p = model.predict(test.x)
        trues.append(test.y)
        preds.append(p)
        per_subject[s] = float(f1_score(test.y, p, average="macro", zero_division=0))
        log(f"  · {s}: F1 {per_subject[s]:.3f} ({len(test)} ventanas)")
    return LosoResult(kind, np.concatenate(trues), np.concatenate(preds), per_subject)


# ----------------------------------------------------------------- contador
@dataclass
class CountResult:
    rows: list[tuple[str, int, str, int, int]]   # (grabación, ejercicio, ritmo, real, contado)
    nulo_reps_per_min: float

    @property
    def errors(self) -> np.ndarray:
        return np.array([c - t for *_, t, c in self.rows])

    def report(self) -> str:
        e = self.errors
        if not len(e):
            return "Contador: no hay series etiquetadas."
        lines = [
            f"Contador ({len(e)} series): error medio {np.abs(e).mean():.2f} reps · exacto {np.mean(e == 0):.0%} · ±1 {np.mean(np.abs(e) <= 1):.0%}"
            f" · de más {np.mean(e > 0):.0%} · de menos {np.mean(e < 0):.0%}",
            f"  Durante NULO (sin clasificador): {self.nulo_reps_per_min:.1f} reps/min falsas — el modelo debe bloquearlas",
        ]
        by_ex: dict[int, list[int]] = {}
        for _, ex, _, t, c in self.rows:
            by_ex.setdefault(ex, []).append(c - t)
        for ex, errs in sorted(by_ex.items()):
            errs = np.array(errs)
            lines.append(f"  {ex} {CLASSES[ex]:<26} error medio {np.abs(errs).mean():.2f} · ±1 {np.mean(np.abs(errs) <= 1):.0%}")
        return "\n".join(lines)


COUNT_PAD_MS = 600   # la última repetición se completa cuando la señal filtrada vuelve al reposo, justo después de la serie


def evaluate_counter(recordings: list[Recording], params: RepParams = FIRMWARE_PARAMS, default_reps: int = 10) -> CountResult:
    """Real = marcas de repetición si las hay; si no, las del protocolo (10 por serie)."""
    rows = []
    nulo_reps, nulo_min = 0, 0.0
    for r in recordings:
        x = mirror(r.x, r.arm)
        for s in r.sets:
            if s.exercise_id == 0:
                continue
            seg = x[(r.t_ms >= s.start_ms) & (r.t_ms < s.end_ms + COUNT_PAD_MS)]
            truth = len(s.rep_markers) or default_reps
            rows.append((r.name, s.exercise_id, s.speed, truth, count_reps(seg, params)))
        lab = r.sample_labels()
        nulo = x[lab == 0]
        nulo_reps += count_reps(nulo, params)
        nulo_min += len(nulo) / 50 / 60
    return CountResult(rows, nulo_reps / nulo_min if nulo_min else 0.0)
