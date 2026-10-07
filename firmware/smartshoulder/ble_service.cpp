#include <Arduino.h>
#include <ArduinoBLE.h>
#include "config.h"
#include "ble_service.h"

static BLEService ssService(UUID_SERVICE);
static BLECharacteristic controlChar(UUID_CONTROL, BLEWrite | BLEWriteWithoutResponse, 20);
static BLECharacteristic eventsChar(UUID_EVENTS, BLENotify, 12, true);
static BLECharacteristic rawChar(UUID_RAW_STREAM, BLENotify, 4 + 12 * RAW_BATCH_MAX);
static BLECharacteristic statusChar(UUID_STATUS, BLERead | BLENotify, 6, true);

static BLEService batteryService("180F");
static BLEUnsignedCharCharacteristic batteryChar("2A19", BLERead | BLENotify);

static CommandHandler commandHandler = nullptr;
static char deviceName[8] = "SS-0000";
static uint8_t statusValue[6] = {0};

static void onControlWritten(BLEDevice, BLECharacteristic c) {
  if (commandHandler && c.valueLength() > 0) commandHandler(c.value(), c.valueLength());
}

bool bleBegin(CommandHandler onCommand) {
  commandHandler = onCommand;
  if (!BLE.begin()) return false;

  // Nombre corto a partir de los 2 últimos bytes de la MAC ("aa:bb:cc:dd:ee:ff" → "SS-EEFF").
  String addr = BLE.address();
  addr.toUpperCase();
  snprintf(deviceName, sizeof(deviceName), "SS-%c%c%c%c",
           addr.charAt(12), addr.charAt(13), addr.charAt(15), addr.charAt(16));

  BLE.setLocalName(deviceName);
  BLE.setDeviceName(deviceName);
  BLE.setAdvertisedService(ssService);

  ssService.addCharacteristic(controlChar);
  ssService.addCharacteristic(eventsChar);
  ssService.addCharacteristic(rawChar);
  ssService.addCharacteristic(statusChar);
  BLE.addService(ssService);

  batteryService.addCharacteristic(batteryChar);
  BLE.addService(batteryService);

  controlChar.setEventHandler(BLEWritten, onControlWritten);
  statusChar.writeValue(statusValue, sizeof(statusValue));
  batteryChar.writeValue(100);

  BLE.advertise();
  return true;
}

void blePoll() { BLE.poll(); }

bool bleConnected() { return BLE.connected(); }

const char *bleName() { return deviceName; }

void bleSetStatus(uint8_t state, uint8_t mode, uint8_t arm, uint8_t rawBatch) {
  uint8_t v[6] = {state, mode, arm, FW_VERSION, MODEL_VERSION, rawBatch};
  if (memcmp(v, statusValue, sizeof(v)) == 0) return;
  memcpy(statusValue, v, sizeof(v));
  statusChar.writeValue(statusValue, sizeof(statusValue));
}

void bleSetBattery(uint8_t pct) {
  if (batteryChar.value() != pct) batteryChar.writeValue(pct);
}

bool bleSendRaw(uint32_t firstIndex, const ImuSample *samples, uint8_t n) {
  if (!BLE.connected() || !rawChar.subscribed()) return false;
  uint8_t buf[4 + 12 * RAW_BATCH_MAX];
  memcpy(buf, &firstIndex, 4);                    // nRF52 es little-endian, igual que el contrato
  memcpy(buf + 4, samples, 12 * n);
  return rawChar.writeValue(buf, 4 + 12 * n) == 1;
}

bool bleSendEvent(const uint8_t event[12]) {
  if (!BLE.connected() || !eventsChar.subscribed()) return false;
  return eventsChar.writeValue(event, 12) == 1;
}
