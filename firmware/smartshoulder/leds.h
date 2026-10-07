#pragma once

// LED RGB de la XIAO (ánodo común: LOW = encendido).
enum LedColor { COLOR_OFF, COLOR_RED, COLOR_GREEN, COLOR_BLUE };

void ledsBegin();
void ledSet(LedColor c);
void ledIdentify();          // parpadeo azul de 3 s
void ledsUpdate(bool connected, bool session, bool lowBattery);
