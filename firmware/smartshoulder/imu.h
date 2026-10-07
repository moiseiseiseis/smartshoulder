#pragma once
#include <stdint.h>

// Una muestra cruda del LSM6DS3TR-C, en el orden del contrato: ax, ay, az, gx, gy, gz.
struct ImuSample {
  int16_t v[6];
};

bool imuBegin();
bool imuRead(ImuSample &out);
