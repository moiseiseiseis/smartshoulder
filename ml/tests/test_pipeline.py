import numpy as np
import pytest

from rumbo_ml.config import WINDOW
from rumbo_ml.data import Recording, SetLabel, contiguous_runs, load_dataset
from rumbo_ml.preprocess import Normalizer, estimate_mirror_axis, mirror, mirror_signs
from rumbo_ml.repcounter import count_reps
from rumbo_ml.synthetic import _exercise, _nulo, generate
from rumbo_ml.windows import label_window, make_windows

rng = np.random.default_rng(0)


# ---------------------------------------------------------------- etiquetado
def test_label_window_rules():
    assert label_window(np.array([2] * 80 + [0] * 20)) == 2          # 80 % → ejercicio
    assert label_window(np.array([2] * 79 + [0] * 21)) is None       # ambigua → se descarta
    assert label_window(np.array([2] * 20 + [0] * 80)) == 0          # ≤ 20 % → NULO
    assert label_window(np.array([1] * 50 + [2] * 50)) is None       # dos ejercicios: ninguno llega a 80 %


def test_windows_never_cross_gaps():
    t = np.r_[np.arange(0, 150) * 20, np.arange(200, 400) * 20]      # hueco entre 150 y 200
    assert contiguous_runs(t) == [(0, 150), (150, 350)]
    rec = Recording("S01_R_x", "S01", "R", t, np.zeros((len(t), 6), np.float32), [])
    w = make_windows(rec, step=50)
    # tramo 1: ventanas en 0 y 50; tramo 2 (200 muestras): 0, 50, 100
    assert len(w) == 5 and (w.y == 0).all()


def test_set_labels_cover_samples():
    t = np.arange(300) * 20
    rec = Recording("S01_R_x", "S01", "R", t, np.zeros((300, 6), np.float32), [SetLabel(1000, 4000, 3, 1, "normal")])
    y = rec.sample_labels()
    assert (y[50:200] == 3).all() and y[:50].sum() == 0 and y[200:].sum() == 0


# ---------------------------------------------------------------- espejado y normalización
def test_mirror_is_involution_and_flips_pseudovector():
    s = mirror_signs("y")
    assert s.tolist() == [1, -1, 1, -1, 1, -1]
    x = rng.normal(size=(10, 6)).astype(np.float32)
    assert np.allclose(mirror(mirror(x, "L"), "L"), x)
    assert np.allclose(mirror(x, "R"), x)


def test_estimate_mirror_axis_finds_true_axis():
    right, _ = _exercise(3, "normal", 6, rng, 1.0)        # rotación externa
    left = right * mirror_signs("y")                        # así se vería con el brazo izquierdo
    scores = estimate_mirror_axis(right, left)
    assert min(scores, key=scores.get) == "y"


def test_normalizer():
    x = rng.normal(5, 3, size=(200, WINDOW, 6)).astype(np.float32)
    n = Normalizer.fit(x)
    z = n(x)
    assert np.allclose(z.reshape(-1, 6).mean(0), 0, atol=1e-3) and np.allclose(z.reshape(-1, 6).std(0), 1, atol=1e-3)


# ---------------------------------------------------------------- contador (misma lógica que el firmware)
@pytest.mark.parametrize("ex", [1, 2, 3, 4, 5])
@pytest.mark.parametrize("speed", ["normal", "lenta", "rapida"])
def test_counter_counts_clean_reps(ex, speed):
    x, _ = _exercise(ex, speed, 10, np.random.default_rng(ex), 1.0)
    rest = np.tile(x[-1:], (30, 1))                       # 0.6 s quieto al final, como en una serie real
    assert abs(count_reps(np.concatenate([x, rest])) - 10) <= 1


def test_counter_ignores_rest():
    rest = np.zeros((50 * 30, 6), np.float32)
    rest[:, 2] = -1
    rest += np.random.default_rng(1).normal(0, 1, rest.shape) * [0.01, 0.01, 0.01, 2, 2, 2]
    assert count_reps(rest) == 0


# ---------------------------------------------------------------- de punta a punta (pequeño)
def test_end_to_end_export(tmp_path):
    from rumbo_ml.config import STEP_TRAIN
    from rumbo_ml.export import export
    from rumbo_ml.pipeline import fit_cnn
    from rumbo_ml.windows import windows_from

    generate(tmp_path / "ds", subjects=2)
    recs = load_dataset(tmp_path / "ds")
    assert {r.arm for r in recs} == {"R"}
    train = windows_from(recs, STEP_TRAIN * 3)
    trained = fit_cnn(train, epochs=1, augment_copies=0)
    card = export(trained, train, tmp_path / "out", 99, {})
    assert (tmp_path / "out" / "model_data.h").read_text().count("g_model_len") == 1
    cfg = (tmp_path / "out" / "model_config.h").read_text()
    assert "MODEL_MEAN[6]" in cfg and "MODEL_INPUT_SCALE" in cfg
    assert card["tflite_bytes"] < 100_000                    # presupuesto de flash (contexto/03 §7)
    assert set(card["ops"]) <= {"RESHAPE", "CONV_2D", "MAX_POOL_2D", "MEAN", "FULLY_CONNECTED", "SOFTMAX", "QUANTIZE", "DEQUANTIZE"}


# ---------------------------------------------------------------- paridad con el firmware real
def test_parity_with_real_xiao_capture():
    """Grabación real (7 oct 2026): la XIAO contó estas 16 repeticiones; Python debe contar exactamente las mismas.
    El contador del firmware arrancó con `expect` cerca de la muestra 6 (cualquier arranque entre 4 y 7 coincide)."""
    from pathlib import Path

    from rumbo_ml.parity import python_reps

    d = np.loadtxt(Path(__file__).parent / "data" / "paridad_flexion_xiao.csv", delimiter=",", skiprows=1, dtype=np.int64)
    samples = [(int(r[0]), r[1:].tolist()) for r in d]
    firmware = [284, 372, 578, 724, 995, 1093, 1190, 1371, 1505, 1678, 1816, 1996, 2419, 2634, 2737, 2804]
    assert python_reps(samples, start=6) == firmware


# ---------------------------------------------------------------- orientación (control de calidad)
def test_hanging_gravity_and_rotated_watch():
    from rumbo_ml.qc import angle_deg, hanging_gravity

    t = np.arange(600) * 20
    still = np.tile([0.0, -1.0, 0.0, 0.0, 0.0, 0.0], (600, 1)).astype(np.float32)   # brazo colgando: gravedad en -y
    still[:, 3:] += np.random.default_rng(0).normal(0, 1, (600, 3))
    g = hanging_gravity(Recording("S01_R_x", "S01", "R", t, still, []))
    assert g is not None and angle_deg(g, np.array([0, -1, 0])) < 3

    rotated = still.copy()
    rotated[:, :3] = [0.0, 0.0, -1.0]                                               # reloj girado 90°
    g2 = hanging_gravity(Recording("S02_R_x", "S02", "R", t, rotated, []))
    assert angle_deg(g, g2) > 80

    moving = still.copy()
    moving[:, 4] += 60 * np.sin(np.arange(600) / 5)                                  # nunca estuvo quieto
    assert hanging_gravity(Recording("S03_R_x", "S03", "R", t, moving, [])) is None
