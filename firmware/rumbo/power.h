#pragma once
#include <stdint.h>

void powerBegin();
uint8_t batteryPercent();   // estimación por voltaje de la LiPo
float batteryVolts();
bool batteryPresent();      // false si no hay LiPo conectada (solo USB)
bool usbPowered();          // hay voltaje en el USB-C (cargando o conectado a la PC)
void powerOff();            // System OFF: no regresa; se enciende al conectar el USB-C o con reset
