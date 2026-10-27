#pragma once
#include <stdint.h>
#include "imu.h"

// Contador de repeticiones por señal (contexto/03 §6). Una repetición = ida y vuelta en el eje con más movimiento.
// Los umbrales y la señal (giroscopio o acelerómetro sin gravedad) dependen del ejercicio esperado.
// En el firmware v2 el clasificador decide si cada repetición detectada es del ejercicio esperado (rumbo.ino).
struct RepParams {
  bool accel;        // false = giroscopio (dps); true = acelerómetro sin gravedad (cg = g × 100)
  float tHigh;       // inicio de movimiento
  float tLow;        // reposo (histéresis)
  uint32_t minRep;   // muestras mínimas por repetición
};

class RepCounter {
public:
  void configure(uint8_t exerciseId);   // elige los umbrales del ejercicio (y reinicia)
  void reset();
  // Devuelve true si con esta muestra se completó una repetición.
  bool update(const ImuSample &s);

private:
  enum Phase { IDLE, OUT, BACK };
  RepParams p = {false, 25.0f, 10.0f, 40};
  float base[3] = {0, 0, 0};    // línea base del acelerómetro (gravedad)
  bool warm = false;
  float lp[3] = {0, 0, 0};      // señal filtrada
  float energy[3] = {0, 0, 0};  // energía lenta por eje, para elegir el eje dominante
  Phase phase = IDLE;
  int axis = 0;
  int sign = 1;
  uint32_t samplesInRep = 0;
  uint32_t samplesSinceRep = 1000;
};
