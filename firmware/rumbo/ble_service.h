#pragma once
#include <stdint.h>
#include "imu.h"

// Callback para comandos de CONTROL (los mismos que llegan por consola serial).
typedef void (*CommandHandler)(const uint8_t *data, int len);

bool bleBegin(CommandHandler onCommand);
void blePoll();
bool bleConnected();
void bleSetStatus(uint8_t state, uint8_t mode, uint8_t arm, uint8_t rawBatch);
void bleSetBattery(uint8_t pct);
bool bleSendRaw(uint32_t firstIndex, const ImuSample *samples, uint8_t n);
bool bleSendEvent(const uint8_t event[12]);   // notificación EVENTS (12 bytes)
const char *bleName();
