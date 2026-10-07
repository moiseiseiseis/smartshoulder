// Constantes del firmware SmartShoulder.
// El contrato BLE vive en contracts/ble.md: cualquier cambio aquí se refleja allá.
#pragma once
#include <stdint.h>

#define FW_VERSION        2   // 1.1 en los docs: inferencia provisional sin modelo
#define MODEL_VERSION     0   // 0 = sin modelo (solo captura)

// ---------- IMU ----------
// Mismos rangos en captura e inferencia: si cambian, hay que reentrenar.
#define IMU_I2C_ADDR      0x6A
#define IMU_ACCEL_RANGE_G 4
#define IMU_GYRO_RANGE_DPS 500
#define IMU_ODR_HZ        104
#define SAMPLE_PERIOD_US  20000UL   // 50 Hz

// ---------- BLE ----------
#define SS_UUID(x) "0ed8" x "-8e11-4ac8-bea3-882874982696"
#define UUID_SERVICE    SS_UUID("0001")
#define UUID_CONTROL    SS_UUID("0002")
#define UUID_EVENTS     SS_UUID("0003")
#define UUID_RAW_STREAM SS_UUID("0004")
#define UUID_STATUS     SS_UUID("0005")

// Muestras por paquete de RAW_STREAM: 4 + 12*N bytes. ArduinoBLE no expone el MTU negociado,
// así que el central lo indica en START_SESSION. Con MTU 23 solo cabe N = 1; con MTU >= 103, N = 8.
#define RAW_BATCH_MAX     8
#define RAW_BATCH_MIN     1

enum Cmd : uint8_t {
  CMD_START_SESSION = 0x01,
  CMD_STOP_SESSION  = 0x02,
  CMD_SET_ARM       = 0x03,
  CMD_SET_MODE      = 0x04,
  CMD_SET_EXPECTED  = 0x05,
  CMD_SYNC_EVENTS   = 0x06,
  CMD_IDENTIFY      = 0x07,
};

// ---------- Eventos ----------
#define EVT_REP              1
#define EVT_EXERCISE_CHANGED 2
#define EVT_SESSION_END      3
#define EVENT_LOG_SIZE       256

enum DevState : uint8_t { STATE_IDLE = 0, STATE_SESSION = 1, STATE_LOW_BATTERY = 2 };
enum DevMode  : uint8_t { MODE_INFERENCE = 0, MODE_CAPTURE = 1 };
enum Arm      : uint8_t { ARM_RIGHT = 0, ARM_LEFT = 1 };

// ---------- Energía ----------
#define LOW_BATTERY_PCT   15
