#include <math.h>
#include "config.h"
#include "repcounter.h"

// A 50 Hz. Valores provisionales, a calibrar con el dataset (contexto/03 §6, punto 5).
// Copia exacta en ml/smartshoulder_ml/repcounter.py: si cambias algo aquí, cámbialo allá.
static const float GYRO_SCALE = 0.0175f;   // crudo → dps (±500 dps)
static const float LP_ALPHA = 0.25f;       // pasa-bajas de 1er orden (~2–3 Hz)
static const float ENERGY_ALPHA = 0.02f;   // ventana lenta (~1 s) para el eje dominante
static const float T_HIGH = 25.0f;         // dps: inicio de movimiento (30 no alcanzaba rotaciones lentas de ~60°)
static const float T_LOW = 10.0f;          // dps: reposo (histéresis)
static const uint32_t MIN_REP = 40;        // 0.8 s: una repetición de fisio rara vez dura menos
static const uint32_t MAX_REP = 500;       // 10 s: si no regresa, se descarta
static const uint32_t REFRACTORY = 15;     // 0.3 s entre repeticiones

void RepCounter::reset() {
  for (int i = 0; i < 3; i++) { lp[i] = 0; energy[i] = 0; }
  phase = IDLE;
  samplesInRep = 0;
  samplesSinceRep = 1000;
}

bool RepCounter::update(const ImuSample &s) {
  for (int i = 0; i < 3; i++) {
    float g = s.v[3 + i] * GYRO_SCALE;
    lp[i] += LP_ALPHA * (g - lp[i]);
    energy[i] += ENERGY_ALPHA * (lp[i] * lp[i] - energy[i]);
  }
  samplesSinceRep++;

  switch (phase) {
    case IDLE: {
      if (samplesSinceRep < REFRACTORY) return false;
      // El eje se fija al iniciar el movimiento y no cambia hasta terminar la repetición.
      int best = 0;
      for (int i = 1; i < 3; i++) if (energy[i] > energy[best]) best = i;
      if (fabsf(lp[best]) > T_HIGH) {
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
      if (lp[axis] * -sign > T_HIGH) phase = BACK;   // empezó el regreso (signo contrario)
      return false;
    case BACK:
      samplesInRep++;
      if (samplesInRep > MAX_REP) { phase = IDLE; return false; }
      if (fabsf(lp[axis]) < T_LOW) {                  // terminó el regreso
        phase = IDLE;
        if (samplesInRep < MIN_REP) return false;
        samplesSinceRep = 0;
        return true;
      }
      return false;
  }
  return false;
}
