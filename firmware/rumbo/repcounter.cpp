#include <math.h>
#include "config.h"
#include "repcounter.h"

// A 50 Hz. Copia exacta de ml/rumbo_ml/repcounter.py: si cambias algo aquí, cámbialo allá.
static const float GYRO_SCALE = 0.0175f;   // crudo → dps (±500 dps)
static const float ACCEL_SCALE = 0.000122f; // crudo → g (±4 g)
static const float LP_ALPHA = 0.25f;       // pasa-bajas de 1er orden (~2–3 Hz)
static const float ENERGY_ALPHA = 0.02f;   // ventana lenta (~1 s) para el eje dominante
static const float BASE_ALPHA = 0.005f;    // línea base del acelerómetro (~4 s)
static const uint32_t MAX_REP = 500;       // 10 s: si no regresa, se descarta
static const uint32_t REFRACTORY = 15;     // 0.3 s entre repeticiones

// Umbrales por exercise_id, calibrados con S01 el 20 oct 2026 (python -m rumbo_ml.calibrate).
static const RepParams DEFAULT_PARAMS = {false, 25.0f, 10.0f, 40};
static const RepParams EXERCISE_PARAMS[7] = {
  {false, 25.0f, 10.0f, 40},   // 0 (sin ejercicio)
  {false, 40.0f, 16.0f, 25},   // 1 Flexión anterior
  {false, 25.0f, 10.0f, 40},   // 2 Abducción
  {false, 10.0f, 3.0f, 25},    // 3 Rotación externa
  {false, 30.0f, 18.0f, 25},   // 4 Rotación interna
  {false, 40.0f, 12.0f, 25},   // 5 Extensión de tríceps
  {true, 8.0f, 2.4f, 25},      // 6 Estabilización escapular: gira poco, se cuenta con el acelerómetro
};

void RepCounter::configure(uint8_t exerciseId) {
  p = exerciseId < 7 ? EXERCISE_PARAMS[exerciseId] : DEFAULT_PARAMS;
  reset();
}

void RepCounter::reset() {
  for (int i = 0; i < 3; i++) { base[i] = 0; lp[i] = 0; energy[i] = 0; }
  warm = false;
  phase = IDLE;
  samplesInRep = 0;
  samplesSinceRep = 1000;
}

bool RepCounter::update(const ImuSample &s) {
  for (int i = 0; i < 3; i++) {
    float g;
    if (p.accel) {
      float a = s.v[i] * ACCEL_SCALE;
      base[i] = warm ? base[i] + BASE_ALPHA * (a - base[i]) : a;
      g = (a - base[i]) * 100.0f;
    } else {
      g = s.v[3 + i] * GYRO_SCALE;
    }
    lp[i] += LP_ALPHA * (g - lp[i]);
    energy[i] += ENERGY_ALPHA * (lp[i] * lp[i] - energy[i]);
  }
  warm = true;
  samplesSinceRep++;

  switch (phase) {
    case IDLE: {
      if (samplesSinceRep < REFRACTORY) return false;
      // El eje se fija al iniciar el movimiento y no cambia hasta terminar la repetición.
      int best = 0;
      for (int i = 1; i < 3; i++) if (energy[i] > energy[best]) best = i;
      if (fabsf(lp[best]) > p.tHigh) {
        axis = best;
        sign = lp[best] > 0 ? 1 : -1;
        phase = OUT;
        samplesInRep = 0;
      }
      return false;
    }
    case OUT:
      samplesInRep++;
      if (samplesInRep > MAX_REP) { phase = IDLE; return false; }
      if (lp[axis] * -sign > p.tHigh) phase = BACK;   // empezó el regreso (signo contrario)
      return false;
    case BACK:
      samplesInRep++;
      if (samplesInRep > MAX_REP) { phase = IDLE; return false; }
      if (fabsf(lp[axis]) < p.tLow) {                 // terminó el regreso
        phase = IDLE;
        if (samplesInRep < p.minRep) return false;
        samplesSinceRep = 0;
        return true;
      }
      return false;
  }
  return false;
}
