#include <Arduino.h>
#include <TensorFlowLite.h>
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/schema/schema_generated.h"
#include "config.h"
#include "classifier.h"
#include "model_config.h"
#include "model_data.h"

static_assert(MODEL_VERSION == MODEL_VERSION_EXPORTED, "MODEL_VERSION de config.h no coincide con model_config.h");
static_assert(MODEL_WINDOW == 100 && MODEL_N_CLASSES == 7, "classifier.h asume ventana de 100 y 7 clases");
static_assert(MODEL_SMOOTHING_VOTES == 3, "classifier.h asume 3 votos");

static const float ACCEL_SCALE_G = 0.000122f;   // mismas escalas que contracts/ble.md
static const float GYRO_SCALE_DPS = 0.0175f;

static constexpr int kArenaSize = 24 * 1024;
alignas(16) static uint8_t arena[kArenaSize];
static tflite::MicroInterpreter *interpreter = nullptr;
static TfLiteTensor *input = nullptr;
static TfLiteTensor *output = nullptr;

bool Classifier::begin() {
  const tflite::Model *model = tflite::GetModel(g_model);
  if (model->version() != TFLITE_SCHEMA_VERSION) { Serial.println("# ERROR: versión de esquema TFLite"); return false; }
  static tflite::MicroMutableOpResolver<6> resolver;   // las ops que lista model_config.h
  resolver.AddConv2D();
  resolver.AddFullyConnected();
  resolver.AddMaxPool2D();
  resolver.AddMean();
  resolver.AddReshape();
  resolver.AddSoftmax();
  static tflite::MicroInterpreter interp(model, resolver, arena, kArenaSize);
  if (interp.AllocateTensors() != kTfLiteOk) { Serial.println("# ERROR: arena insuficiente para el modelo"); return false; }
  interpreter = &interp;
  input = interp.input(0);
  output = interp.output(0);
  Serial.print("# Modelo v"); Serial.print(MODEL_VERSION_EXPORTED);
  Serial.print(" listo, arena usada "); Serial.print(interp.arena_used_bytes()); Serial.println(" B");
  return true;
}

void Classifier::reset() {
  head = 0;
  filled = 0;
  nVotes = 0;
  lastClass = smoothedClass = 0;
}

bool Classifier::push(const ImuSample &s, bool leftArm) {
  if (!interpreter) return false;
  for (int c = 0; c < 6; c++) {
    float x = s.v[c] * (c < 3 ? ACCEL_SCALE_G : GYRO_SCALE_DPS);
    if (leftArm) x *= MODEL_MIRROR_SIGNS[c];
    float z = (x - MODEL_MEAN[c]) / MODEL_STD[c];
    long q = lroundf(z / MODEL_INPUT_SCALE) + MODEL_INPUT_ZERO_POINT;
    window[head][c] = (int8_t)constrain(q, -128L, 127L);
  }
  head = (head + 1) % MODEL_WINDOW;
  filled++;
  // Mismas ventanas que Python: la primera al juntar 100 muestras, luego cada MODEL_STEP.
  if (filled < MODEL_WINDOW || (filled - MODEL_WINDOW) % MODEL_STEP) return false;
  run();
  return true;
}

void Classifier::run() {
  uint32_t t0 = micros();
  int8_t *in = input->data.int8;
  for (int i = 0; i < MODEL_WINDOW; i++) memcpy(in + 6 * i, window[(head + i) % MODEL_WINDOW], 6);   // de la más vieja a la más nueva
  if (interpreter->Invoke() != kTfLiteOk) return;
  uint8_t best = 0;
  for (int k = 0; k < MODEL_N_CLASSES; k++) {
    probs[k] = (output->data.int8[k] - MODEL_OUTPUT_ZERO_POINT) * MODEL_OUTPUT_SCALE;
    if (probs[k] > probs[best]) best = k;
  }
  lastClass = best;
  lastInferenceUs = micros() - t0;

  // Voto mayoritario; con empate gana la ventana más reciente.
  votes[2] = votes[1]; votes[1] = votes[0]; votes[0] = best;
  if (nVotes < 3) nVotes++;
  smoothedClass = best;
  if (nVotes == 3 && votes[1] == votes[2] && votes[1] != best) smoothedClass = votes[1];
}
