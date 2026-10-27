// Generado por ml/rumbo_ml/export.py — no editar a mano.
// Constantes del preprocesamiento: deben ser IDÉNTICAS a las de Python (contexto/03 §3.2).
#pragma once

#define MODEL_VERSION_EXPORTED 1
#define MODEL_WINDOW           100
#define MODEL_STEP             25
#define MODEL_SMOOTHING_VOTES  3
#define MODEL_N_CLASSES        7
#define MODEL_MIRROR_AXIS      1   // 0 = x, 1 = y, 2 = z

// Orden de canales: ax, ay, az, gx, gy, gz (g y dps)
static const float MODEL_MIRROR_SIGNS[6] = {1.00000000f, -1.00000000f, 1.00000000f, -1.00000000f, 1.00000000f, -1.00000000f};   // se aplica si el brazo es el izquierdo
// Clase del modelo para cada exercise_id (ejercicios indistinguibles comparten clase: config.CLASS_MERGE).
static const unsigned char MODEL_CLASS_OF[7] = {0, 1, 2, 3, 3, 5, 6};
static const float MODEL_MEAN[6] = {-0.59819412f, -0.21964595f, 0.35181952f, 0.14183131f, -4.28969383f, -0.01111105f};
static const float MODEL_STD[6]  = {0.38854325f, 0.50901586f, 0.30072322f, 28.90474510f, 28.26831055f, 31.92784500f};

static const float MODEL_INPUT_SCALE = 0.1091844589f;
static const int   MODEL_INPUT_ZERO_POINT = 18;
static const float MODEL_OUTPUT_SCALE = 0.0039062500f;
static const int   MODEL_OUTPUT_ZERO_POINT = -128;

// Operaciones para MicroMutableOpResolver: CONV_2D, FULLY_CONNECTED, MAX_POOL_2D, MEAN, RESHAPE, SOFTMAX
