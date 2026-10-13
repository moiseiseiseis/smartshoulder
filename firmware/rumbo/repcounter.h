#pragma once
#include <stdint.h>
#include "imu.h"

// Contador de repeticiones por señal (contexto/03 §6), SIN clasificador todavía.
// Una repetición = ida y vuelta en el eje del giroscopio con más movimiento.
// Mientras no exista el modelo (MODEL_VERSION 0), cuenta cualquier movimiento de ese tipo
// como repetición del ejercicio que la app indicó con SET_EXPECTED.
class RepCounter {
public:
  void reset();
  // Devuelve true si con esta muestra se completó una repetición.
  bool update(const ImuSample &s);

private:
  enum Phase { IDLE, OUT, BACK };
  float lp[3] = {0, 0, 0};      // giroscopio filtrado (dps)
  float energy[3] = {0, 0, 0};  // energía lenta por eje, para elegir el eje dominante
  Phase phase = IDLE;
  int axis = 0;
  int sign = 1;
  uint32_t samplesInRep = 0;
  uint32_t samplesSinceRep = 1000;
};
