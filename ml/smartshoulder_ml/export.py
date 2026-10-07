"""Exportación al dispositivo (contexto/03 §7–8): int8 completo → model_data.h + model_config.h + model_card.json."""
from __future__ import annotations

import datetime as dt
import json
import subprocess
from pathlib import Path

import numpy as np

from .config import CHANNELS, MIRROR_AXIS, N_CLASSES, SMOOTHING_VOTES, STEP_INFERENCE, WINDOW
from .pipeline import TrainedCnn
from .preprocess import mirror_signs
from .windows import Windows


def to_tflite_int8(trained: TrainedCnn, representative: np.ndarray) -> bytes:
    import tensorflow as tf

    rep = trained.normalizer(representative).astype(np.float32)

    def gen():
        for i in range(len(rep)):
            yield [rep[i : i + 1]]

    from .models import build_cnn

    fixed = build_cnn(batch_size=1)                # lote fijo = como corre en la XIAO
    fixed.set_weights(trained.model.get_weights())
    conv = tf.lite.TFLiteConverter.from_keras_model(fixed)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    conv.representative_dataset = gen
    conv.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    conv.inference_input_type = tf.int8
    conv.inference_output_type = tf.int8
    return conv.convert()


class Int8Model:
    """Corre el .tflite cuantizado exactamente como lo hará la XIAO (entrada y salida int8)."""

    def __init__(self, tflite: bytes):
        import tensorflow as tf

        # Sin delegados (XNNPACK): kernels de referencia, los más parecidos a TFLite Micro.
        self.it = tf.lite.Interpreter(
            model_content=tflite,
            experimental_op_resolver_type=tf.lite.experimental.OpResolverType.BUILTIN_WITHOUT_DEFAULT_DELEGATES,
        )
        self.it.allocate_tensors()
        self.inp = self.it.get_input_details()[0]
        self.out = self.it.get_output_details()[0]
        self.in_scale, self.in_zp = self.inp["quantization"]
        self.out_scale, self.out_zp = self.out["quantization"]

    def quantize_input(self, x_norm: np.ndarray) -> np.ndarray:
        return np.clip(np.round(x_norm / self.in_scale + self.in_zp), -128, 127).astype(np.int8)

    def predict_proba(self, x_norm: np.ndarray) -> np.ndarray:
        out = []
        for w in x_norm:
            self.it.set_tensor(self.inp["index"], self.quantize_input(w[None]))
            self.it.invoke()
            q = self.it.get_tensor(self.out["index"])[0].astype(np.float32)
            out.append((q - self.out_zp) * self.out_scale)
        return np.array(out)

    def ops(self) -> list[str]:
        return sorted({d["op_name"] for d in self.it._get_ops_details()})


def _c_array(data: bytes, name: str) -> str:
    rows = [", ".join(f"0x{b:02x}" for b in data[i : i + 12]) for i in range(0, len(data), 12)]
    body = ",\n  ".join(rows)
    return (
        "// Generado por ml/smartshoulder_ml/export.py — no editar a mano.\n#pragma once\n#include <stdint.h>\n\n"
        f"alignas(16) const unsigned char {name}[] = {{\n  {body}\n}};\nconst unsigned int {name}_len = {len(data)};\n"
    )


def _floats(v) -> str:
    return "{" + ", ".join(f"{float(x):.8f}f" for x in v) + "}"


def model_config_h(version: int, trained: TrainedCnn, m: Int8Model) -> str:
    return f"""// Generado por ml/smartshoulder_ml/export.py — no editar a mano.
// Constantes del preprocesamiento: deben ser IDÉNTICAS a las de Python (contexto/03 §3.2).
#pragma once

#define MODEL_VERSION_EXPORTED {version}
#define MODEL_WINDOW           {WINDOW}
#define MODEL_STEP             {STEP_INFERENCE}
#define MODEL_SMOOTHING_VOTES  {SMOOTHING_VOTES}
#define MODEL_N_CLASSES        {N_CLASSES}
#define MODEL_MIRROR_AXIS      {"xyz".index(MIRROR_AXIS)}   // 0 = x, 1 = y, 2 = z

// Orden de canales: {", ".join(CHANNELS)} (g y dps)
static const float MODEL_MIRROR_SIGNS[6] = {_floats(mirror_signs())};   // se aplica si el brazo es el izquierdo
static const float MODEL_MEAN[6] = {_floats(trained.normalizer.mean)};
static const float MODEL_STD[6]  = {_floats(trained.normalizer.std)};

static const float MODEL_INPUT_SCALE = {m.in_scale:.10f}f;
static const int   MODEL_INPUT_ZERO_POINT = {int(m.in_zp)};
static const float MODEL_OUTPUT_SCALE = {m.out_scale:.10f}f;
static const int   MODEL_OUTPUT_ZERO_POINT = {int(m.out_zp)};

// Operaciones para MicroMutableOpResolver: {", ".join(m.ops())}
"""


def git_commit() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "sin-git"


def export(trained: TrainedCnn, train: Windows, out_dir: Path, version: int, card_extra: dict, rng_seed: int = 0) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(rng_seed)
    rep_idx = rng.choice(len(train), size=min(500, len(train)), replace=False)
    tflite = to_tflite_int8(trained, train.x[rep_idx])
    m = Int8Model(tflite)

    # ¿El int8 decide igual que el float? (sobre una muestra de ventanas)
    idx = rng.choice(len(train), size=min(1000, len(train)), replace=False)
    xn = trained.normalizer(train.x[idx])
    agree = float((m.predict_proba(xn).argmax(1) == trained.model.predict(xn, verbose=0).argmax(1)).mean())

    (out_dir / "model.tflite").write_bytes(tflite)
    (out_dir / "model_data.h").write_text(_c_array(tflite, "g_model"), encoding="utf-8")
    (out_dir / "model_config.h").write_text(model_config_h(version, trained, m), encoding="utf-8")
    card = {
        "version": f"model_v{version}",
        "date": dt.datetime.now().isoformat(timespec="seconds"),
        "commit": git_commit(),
        "tflite_bytes": len(tflite),
        "params": int(trained.model.count_params()),
        "ops": m.ops(),
        "int8_agreement_with_float": round(agree, 4),
        "normalization": trained.normalizer.to_dict(),
        "mirror_axis": MIRROR_AXIS,
        "window": WINDOW,
        "step": STEP_INFERENCE,
        **card_extra,
    }
    (out_dir / "model_card.json").write_text(json.dumps(card, indent=2, ensure_ascii=False), encoding="utf-8")
    return card
