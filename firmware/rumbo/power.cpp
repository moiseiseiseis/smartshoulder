#include <Arduino.h>
#include "config.h"
#include "power.h"

// Divisor de la XIAO: VBAT → 1 MΩ / 510 kΩ → P0.31. Calibrar VBAT_CAL contra un multímetro.
static const float VBAT_DIVIDER = 1510.0f / 510.0f;
static const float ADC_REF_V = 3.3f;
static const float VBAT_CAL = 1.0f;

void powerBegin() {
  // P0.14 en LOW habilita el divisor. Seeed advierte que en HIGH el pin P0.31 puede superar 3.6 V: nunca subirlo.
  pinMode(P0_14, OUTPUT);
  digitalWrite(P0_14, LOW);
  // P0.13 en HIGH = carga a 50 mA (LiPo pequeña, ≤ 200 mAh: no cargar a más de ~1C).
  pinMode(P0_13, OUTPUT);
  digitalWrite(P0_13, HIGH);
  analogReadResolution(12);
}

float batteryVolts() {
  return analogRead(P0_31) * ADC_REF_V / 4095.0f * VBAT_DIVIDER * VBAT_CAL;
}

bool batteryPresent() { return batteryVolts() > 2.5f; }

uint8_t batteryPercent() {
  // Curva aproximada de LiPo, lineal por tramos.
  static const float v[] = {3.30f, 3.60f, 3.70f, 3.80f, 3.90f, 4.00f, 4.20f};
  static const uint8_t p[] = {0, 10, 25, 45, 65, 80, 100};
  float x = batteryVolts();
  if (x <= v[0]) return 0;
  for (int i = 1; i < 7; i++) {
    if (x <= v[i]) return p[i - 1] + (uint8_t)((x - v[i - 1]) / (v[i] - v[i - 1]) * (p[i] - p[i - 1]));
  }
  return 100;
}
