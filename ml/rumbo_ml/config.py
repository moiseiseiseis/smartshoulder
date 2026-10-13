"""Constantes del modelo (contexto/03). Las que usa el firmware se exportan a model_config.h."""

FS_HZ = 50
SAMPLE_MS = 1000 // FS_HZ          # 20 ms
WINDOW = 100                       # 2 s
STEP_INFERENCE = 25                # 0.5 s (75 % de traslape)
STEP_TRAIN = 10                    # más ventanas para entrenar
LABEL_MIN_FRACTION = 0.8           # ≥ 80 % dentro de la serie → etiqueta del ejercicio
AMBIGUOUS_MAX_FRACTION = 0.2       # entre 20 % y 80 %: ventana ambigua, se descarta
SMOOTHING_VOTES = 3                # voto mayoritario sobre las últimas N ventanas (firmware)

CHANNELS = ["ax", "ay", "az", "gx", "gy", "gz"]

# Mismas escalas que el firmware y contracts/ble.md (±4 g, ±500 dps).
ACCEL_SCALE_G = 0.000122
GYRO_SCALE_DPS = 0.0175
ACCEL_RANGE_G = 4.0
GYRO_RANGE_DPS = 500.0

CLASSES = {
    0: "NULO",
    1: "Flexión anterior",
    2: "Abducción",
    3: "Rotación externa",
    4: "Rotación interna",
    5: "Extensión de tríceps",
    6: "Estabilización escapular",
}
N_CLASSES = len(CLASSES)

# Espejado izquierda → derecha (contexto/03 §3.2): se fija EMPÍRICAMENTE el primer día de captura
# con preprocess.estimate_mirror_axis(). Valor provisional: eje Y del dispositivo.
# Reflejar a través de un plano invierte la componente del acelerómetro perpendicular al plano
# y las dos componentes del giroscopio paralelas a él (la velocidad angular es un pseudovector).
MIRROR_AXIS = "y"

# Metas para Demo Day (contexto/03 §5)
TARGET_F1_MACRO = 0.90
TARGET_COUNT_WITHIN_1 = 0.90
TARGET_NULO_FALSE_POSITIVE = 0.05
