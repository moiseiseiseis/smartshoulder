#pragma once
#include <stdint.h>

void powerBegin();
uint8_t batteryPercent();   // estimación por voltaje de la LiPo
float batteryVolts();
bool batteryPresent();      // false si no hay LiPo conectada (solo USB)
