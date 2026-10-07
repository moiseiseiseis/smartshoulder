// SmartShoulder — firmware para Seeed XIAO nRF52840 Sense (core "Seeed nRF52 mbed-enabled Boards").
// Versión 1: modo captura (dataset) por BLE y por USB serial.
// Versión 1.1: modo inferencia PROVISIONAL: cuenta repeticiones por señal (repcounter) sin clasificador;
//              la repetición se atribuye al ejercicio que la app indica con SET_EXPECTED. El modelo llega en la v2.
// Contrato: contracts/ble.md

#include <Arduino.h>
#include "config.h"
#include "imu.h"
#include "ble_service.h"
#include "power.h"
#include "leds.h"
#include "repcounter.h"

// ---------- Estado ----------
static DevMode mode = MODE_CAPTURE;
static Arm arm = ARM_RIGHT;
static bool sessionActive = false;
static bool sessionFromSerial = false;   // la sesión la inició la consola serial (no se corta al perder BLE)
static bool lowBattery = false;
static bool imuOk = false;

static uint32_t sampleIndex = 0;
static unsigned long nextSampleUs = 0;
static uint32_t lateSamples = 0;         // muestras que no se pudieron tomar a tiempo (diagnóstico)

static ImuSample batch[RAW_BATCH_MAX];
static uint8_t batchCount = 0;
static uint32_t batchFirstIndex = 0;
static uint8_t rawBatch = RAW_BATCH_MIN;

// ---------- Inferencia (eventos) ----------
static RepCounter repCounter;
static uint8_t expectedExercise = 0;
static uint16_t repInSet = 0;
static uint16_t eventSeq = 0;
static unsigned long sessionStartMs = 0;
static uint8_t eventLog[EVENT_LOG_SIZE][12];   // últimos eventos, para SYNC_EVENTS tras una reconexión
static int32_t syncFrom = -1;                  // seq pendiente de reenviar (se procesa en loop, no en el callback BLE)

static void emitEvent(uint8_t type, uint8_t exerciseId, uint16_t repIndex, uint8_t confidence) {
  uint8_t e[12];
  uint32_t ts = millis() - sessionStartMs;
  e[0] = type; e[1] = exerciseId;
  e[2] = repIndex & 0xff; e[3] = repIndex >> 8;
  e[4] = confidence; e[5] = 0;
  memcpy(e + 6, &ts, 4);
  e[10] = eventSeq & 0xff; e[11] = eventSeq >> 8;
  memcpy(eventLog[eventSeq % EVENT_LOG_SIZE], e, 12);
  eventSeq++;
  bleSendEvent(e);   // si no hay conexión se pierde la notificación, pero queda en eventLog
}

static void processSync() {
  if (syncFrom < 0 || !bleConnected()) return;
  uint16_t from = syncFrom;
  if ((uint16_t)(eventSeq - from) > EVENT_LOG_SIZE) from = eventSeq - EVENT_LOG_SIZE;
  for (uint16_t s = from; s != eventSeq; s++) bleSendEvent(eventLog[s % EVENT_LOG_SIZE]);
  syncFrom = -1;
}

// ---------- Sesión ----------
static void startSession(bool fromSerial, uint8_t requestedBatch) {
  if (!imuOk) { Serial.println("# ERROR: IMU no inicializado"); return; }
  sessionActive = true;
  sessionFromSerial = fromSerial;
  sampleIndex = 0;
  lateSamples = 0;
  batchCount = 0;
  rawBatch = constrain(requestedBatch, RAW_BATCH_MIN, RAW_BATCH_MAX);
  nextSampleUs = micros();
  sessionStartMs = millis();
  eventSeq = 0;
  expectedExercise = 0;
  repInSet = 0;
  repCounter.reset();
  Serial.print("# START mode="); Serial.print(mode == MODE_CAPTURE ? "capture" : "inference");
  Serial.print(" arm="); Serial.print(arm == ARM_RIGHT ? "R" : "L");
  Serial.print(" batch="); Serial.println(rawBatch);
}

static void stopSession() {
  if (!sessionActive) return;
  if (mode == MODE_INFERENCE) emitEvent(EVT_SESSION_END, expectedExercise, repInSet, 0);
  sessionActive = false;
  Serial.print("# STOP samples="); Serial.print(sampleIndex);
  Serial.print(" late="); Serial.println(lateSamples);
}

// Comandos binarios de CONTROL (BLE). La consola serial los traduce a este mismo formato.
static void handleCommand(const uint8_t *d, int len, bool fromSerial) {
  switch (d[0]) {
    case CMD_START_SESSION: startSession(fromSerial, len >= 2 ? d[1] : RAW_BATCH_MIN); break;
    case CMD_STOP_SESSION:  stopSession(); break;
    case CMD_SET_ARM:       if (len >= 2) arm = d[1] == ARM_LEFT ? ARM_LEFT : ARM_RIGHT; break;
    case CMD_SET_MODE:      if (len >= 2 && !sessionActive) mode = d[1] == MODE_INFERENCE ? MODE_INFERENCE : MODE_CAPTURE; break;
    case CMD_SET_EXPECTED:
      if (len >= 2) {
        expectedExercise = d[1];
        repInSet = 0;
        repCounter.reset();
        if (sessionActive && expectedExercise) emitEvent(EVT_EXERCISE_CHANGED, expectedExercise, 0, 0);
        Serial.print("# EXPECTED "); Serial.print(expectedExercise); Serial.print(" @"); Serial.println(sampleIndex);
      }
      break;
    case CMD_SYNC_EVENTS:   if (len >= 3) syncFrom = d[1] | (d[2] << 8); break;
    case CMD_IDENTIFY:      ledIdentify(); break;
    default:
      Serial.print("# comando desconocido 0x"); Serial.println(d[0], HEX);
  }
}

static void onBleCommand(const uint8_t *d, int len) { handleCommand(d, len, false); }

// ---------- Consola serial ----------
static void printStatus() {
  Serial.print("# name="); Serial.print(bleName());
  Serial.print(" fw="); Serial.print(FW_VERSION);
  Serial.print(" mode="); Serial.print(mode == MODE_CAPTURE ? "capture" : "inference");
  Serial.print(" arm="); Serial.print(arm == ARM_RIGHT ? "R" : "L");
  Serial.print(" session="); Serial.print(sessionActive ? 1 : 0);
  Serial.print(" ble="); Serial.print(bleConnected() ? 1 : 0);
  Serial.print(" imu="); Serial.print(imuOk ? 1 : 0);
  Serial.print(" vbat="); Serial.print(batteryVolts(), 2);
  Serial.print(" bat%="); Serial.println(batteryPercent());
}

static void handleSerialLine(String line) {
  line.trim();
  uint8_t cmd[2];
  if (line == "start")               { cmd[0] = CMD_START_SESSION; handleCommand(cmd, 1, true); }
  else if (line == "stop")           { cmd[0] = CMD_STOP_SESSION; handleCommand(cmd, 1, true); }
  else if (line == "mode capture")   { cmd[0] = CMD_SET_MODE; cmd[1] = MODE_CAPTURE; handleCommand(cmd, 2, true); }
  else if (line == "mode inference") { cmd[0] = CMD_SET_MODE; cmd[1] = MODE_INFERENCE; handleCommand(cmd, 2, true); }
  else if (line == "arm R")          { cmd[0] = CMD_SET_ARM; cmd[1] = ARM_RIGHT; handleCommand(cmd, 2, true); }
  else if (line == "arm L")          { cmd[0] = CMD_SET_ARM; cmd[1] = ARM_LEFT; handleCommand(cmd, 2, true); }
  else if (line.startsWith("expect ")) { cmd[0] = CMD_SET_EXPECTED; cmd[1] = (uint8_t)line.substring(7).toInt(); handleCommand(cmd, 2, true); }
  else if (line == "identify")       { cmd[0] = CMD_IDENTIFY; handleCommand(cmd, 1, true); }
  else if (line == "status")         { printStatus(); }
  else if (line.length() > 0)        { Serial.print("# ? "); Serial.println(line); }
}

static void pollSerial() {
  static String buf;
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') { if (buf.length()) handleSerialLine(buf); buf = ""; }
    else if (buf.length() < 40) buf += c;
  }
}

// ---------- Muestreo ----------
static void emitCaptureSample(const ImuSample &s, uint32_t index) {
  if (sessionFromSerial) {
    char line[64];
    snprintf(line, sizeof(line), "D,%lu,%d,%d,%d,%d,%d,%d", (unsigned long)index,
             s.v[0], s.v[1], s.v[2], s.v[3], s.v[4], s.v[5]);
    Serial.println(line);
    return;
  }
  if (batchCount == 0) batchFirstIndex = index;
  batch[batchCount++] = s;
  if (batchCount >= rawBatch) {
    bleSendRaw(batchFirstIndex, batch, batchCount);
    batchCount = 0;
  }
}

static void sampleTick() {
  long behind = (long)(micros() - nextSampleUs);
  if (behind < 0) return;

  // Si el loop se atrasó más de 2 periodos, se saltan esas muestras (el hueco queda visible en el índice).
  if (behind > (long)(2 * SAMPLE_PERIOD_US)) {
    uint32_t missed = behind / SAMPLE_PERIOD_US;
    sampleIndex += missed;
    lateSamples += missed;
    nextSampleUs += missed * SAMPLE_PERIOD_US;
    batchCount = 0;   // un paquete no puede contener muestras no contiguas
  }
  nextSampleUs += SAMPLE_PERIOD_US;

  ImuSample s;
  if (!imuRead(s)) return;
  if (mode == MODE_CAPTURE) emitCaptureSample(s, sampleIndex);
  else if (sessionFromSerial) {
    // Diagnóstico de paridad (contexto/02 §9): la muestra cruda va antes que su posible REP,
    // para que Python cuente sobre exactamente la misma señal.
    char line[64];
    snprintf(line, sizeof(line), "D,%lu,%d,%d,%d,%d,%d,%d", (unsigned long)sampleIndex, s.v[0], s.v[1], s.v[2], s.v[3], s.v[4], s.v[5]);
    Serial.println(line);
  }
  if (mode == MODE_INFERENCE && expectedExercise && repCounter.update(s)) {
    repInSet++;
    emitEvent(EVT_REP, expectedExercise, repInSet, 0);   // confianza 0 = sin clasificador (MODEL_VERSION 0)
    Serial.print("# REP "); Serial.print(repInSet); Serial.print(" @"); Serial.println(sampleIndex);
  }
  sampleIndex++;
}

// ---------- Arduino ----------
void setup() {
  Serial.begin(115200);
  ledsBegin();
  powerBegin();
  imuOk = imuBegin();
  if (!bleBegin(onBleCommand)) {
    while (true) { ledSet(COLOR_RED); delay(200); ledSet(COLOR_OFF); delay(200); }
  }
  Serial.print("# SmartShoulder fw "); Serial.print(FW_VERSION);
  Serial.print(" listo como "); Serial.println(bleName());
}

void loop() {
  static bool wasConnected = false;
  static unsigned long lastHousekeeping = 0;

  blePoll();
  pollSerial();

  bool connected = bleConnected();
  // En captura se detiene (el crudo ya no llega a nadie); en inferencia el reloj sigue contando y la app pide SYNC al reconectar.
  if (wasConnected && !connected && sessionActive && !sessionFromSerial && mode == MODE_CAPTURE) {
    Serial.println("# BLE perdido: captura detenida");
    stopSession();
  }
  wasConnected = connected;

  if (sessionActive) sampleTick();
  processSync();

  if (millis() - lastHousekeeping > 1000) {
    lastHousekeeping = millis();
    uint8_t pct = batteryPercent();
    lowBattery = batteryPresent() && pct < LOW_BATTERY_PCT;
    bleSetBattery(pct);
    uint8_t state = sessionActive ? STATE_SESSION : (lowBattery ? STATE_LOW_BATTERY : STATE_IDLE);
    bleSetStatus(state, mode, arm, rawBatch);
  }
  ledsUpdate(connected, sessionActive, lowBattery);
}
