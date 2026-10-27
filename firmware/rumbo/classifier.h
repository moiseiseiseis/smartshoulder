#pragma once
#include <stdint.h>
#include "imu.h"

// Clasificador de ejercicio (contexto/03): CNN int8 con TensorFlow Lite Micro.
// Ventana de MODEL_WINDOW muestras (2 s), una inferencia cada MODEL_STEP muestras (0.5 s).
// El preprocesamiento (escalas, espejado, normalización, cuantización) sale de model_config.h,
// idéntico al de ml/rumbo_ml.
class Classifier {
public:
  bool begin();
  void reset();                    // vacía la ventana (inicio de sesión)
  // Agrega una muestra. Devuelve true si con ella corrió el modelo (hay predicción nueva).
  bool push(const ImuSample &s, bool leftArm);

  uint8_t lastClass = 0;           // clase de la última ventana
  uint8_t smoothedClass = 0;       // voto mayoritario de las últimas MODEL_SMOOTHING_VOTES
  float probs[7] = {0};            // probabilidades de la última ventana
  uint32_t lastInferenceUs = 0;    // duración de la última inferencia (diagnóstico)

private:
  void run();
  int8_t window[100][6];           // búfer circular, ya cuantizado a la entrada del modelo
  uint16_t head = 0;
  uint32_t filled = 0;
  uint8_t votes[3] = {0, 0, 0};
  uint8_t nVotes = 0;
};
