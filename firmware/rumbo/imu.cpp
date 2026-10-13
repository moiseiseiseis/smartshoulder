// Driver mínimo del LSM6DS3TR-C interno de la XIAO nRF52840 Sense.
// No se usa la librería "Seeed Arduino LSM6DS3": la 2.0.5 no compila con el core mbed,
// y así los rangos quedan fijos y explícitos aquí (deben coincidir con contracts/ble.md).
#include <Arduino.h>
#include <Wire.h>
#include "config.h"
#include "imu.h"

#define IMU_WIRE      Wire1     // bus I2C interno del IMU
#define REG_WHO_AM_I  0x0F
#define REG_CTRL1_XL  0x10
#define REG_CTRL2_G   0x11
#define REG_CTRL3_C   0x12
#define REG_OUTX_L_G  0x22      // 0x22..0x2D: gx, gy, gz, ax, ay, az

// CTRL1_XL: ODR 104 Hz (0100) | FS ±4 g (10)        → 0100 1000
// CTRL2_G : ODR 104 Hz (0100) | FS ±500 dps (01)    → 0100 0100
// CTRL3_C : BDU = 1 (no mezclar bytes de muestras distintas) | IF_INC = 1 (lectura en ráfaga)
static const uint8_t CTRL1_XL_VALUE = 0x48;
static const uint8_t CTRL2_G_VALUE = 0x44;
static const uint8_t CTRL3_C_VALUE = 0x44;
static_assert(IMU_ACCEL_RANGE_G == 4 && IMU_GYRO_RANGE_DPS == 500 && IMU_ODR_HZ == 104,
              "Actualiza los registros CTRL si cambian los rangos");

static bool writeReg(uint8_t reg, uint8_t value) {
  IMU_WIRE.beginTransmission(IMU_I2C_ADDR);
  IMU_WIRE.write(reg);
  IMU_WIRE.write(value);
  return IMU_WIRE.endTransmission() == 0;
}

static bool readRegs(uint8_t reg, uint8_t *out, uint8_t len) {
  IMU_WIRE.beginTransmission(IMU_I2C_ADDR);
  IMU_WIRE.write(reg);
  if (IMU_WIRE.endTransmission(false) != 0) return false;
  if (IMU_WIRE.requestFrom(IMU_I2C_ADDR, len) != len) return false;
  for (uint8_t i = 0; i < len; i++) out[i] = IMU_WIRE.read();
  return true;
}

bool imuBegin() {
  // Alimentación del IMU (P1.08) con drive alto, igual que la librería de Seeed.
  pinMode(PIN_LSM6DS3TR_C_POWER, OUTPUT);
  NRF_P1->PIN_CNF[8] = ((uint32_t)NRF_GPIO_PIN_DIR_OUTPUT << GPIO_PIN_CNF_DIR_Pos)
                     | ((uint32_t)NRF_GPIO_PIN_INPUT_DISCONNECT << GPIO_PIN_CNF_INPUT_Pos)
                     | ((uint32_t)NRF_GPIO_PIN_NOPULL << GPIO_PIN_CNF_PULL_Pos)
                     | ((uint32_t)NRF_GPIO_PIN_H0H1 << GPIO_PIN_CNF_DRIVE_Pos)
                     | ((uint32_t)NRF_GPIO_PIN_NOSENSE << GPIO_PIN_CNF_SENSE_Pos);
  digitalWrite(PIN_LSM6DS3TR_C_POWER, HIGH);
  delay(20);

  IMU_WIRE.begin();
  IMU_WIRE.setClock(400000);

  uint8_t who = 0;
  if (!readRegs(REG_WHO_AM_I, &who, 1) || who != 0x6A) return false;
  return writeReg(REG_CTRL3_C, CTRL3_C_VALUE) &&
         writeReg(REG_CTRL1_XL, CTRL1_XL_VALUE) &&
         writeReg(REG_CTRL2_G, CTRL2_G_VALUE);
}

bool imuRead(ImuSample &out) {
  uint8_t buf[12];
  if (!readRegs(REG_OUTX_L_G, buf, sizeof(buf))) return false;
  int16_t raw[6];
  for (int i = 0; i < 6; i++) raw[i] = (int16_t)(buf[2 * i] | (buf[2 * i + 1] << 8));
  // El sensor entrega gx, gy, gz, ax, ay, az; el contrato usa ax..az, gx..gz.
  out.v[0] = raw[3]; out.v[1] = raw[4]; out.v[2] = raw[5];
  out.v[3] = raw[0]; out.v[4] = raw[1]; out.v[5] = raw[2];
  return true;
}
