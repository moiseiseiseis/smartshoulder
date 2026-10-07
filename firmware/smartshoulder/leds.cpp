#include <Arduino.h>
#include "leds.h"

static unsigned long identifyUntil = 0;

void ledsBegin() {
  pinMode(LEDR, OUTPUT);
  pinMode(LEDG, OUTPUT);
  pinMode(LEDB, OUTPUT);
  ledSet(COLOR_OFF);
}

void ledSet(LedColor c) {
  digitalWrite(LEDR, c == COLOR_RED ? LOW : HIGH);
  digitalWrite(LEDG, c == COLOR_GREEN ? LOW : HIGH);
  digitalWrite(LEDB, c == COLOR_BLUE ? LOW : HIGH);
}

void ledIdentify() { identifyUntil = millis() + 3000; }

// Verde fijo = sesión/captura activa; azul lento = conectado; azul corto cada 2 s = esperando conexión;
// rojo = batería baja; azul rápido = IDENTIFY.
void ledsUpdate(bool connected, bool session, bool lowBattery) {
  unsigned long now = millis();
  if (now < identifyUntil) { ledSet((now / 150) % 2 ? COLOR_BLUE : COLOR_OFF); return; }
  if (lowBattery)           { ledSet((now / 500) % 2 ? COLOR_RED : COLOR_OFF); return; }
  if (session)              { ledSet(COLOR_GREEN); return; }
  if (connected)            { ledSet((now / 1000) % 2 ? COLOR_BLUE : COLOR_OFF); return; }
  ledSet((now % 2000) < 80 ? COLOR_BLUE : COLOR_OFF);
}
