#!/usr/bin/env bash
# Instala TensorFlow Lite Micro para Arduino (tflite-micro-arduino-examples) adaptado a la XIAO nRF52840 Sense.
# La librería oficial solo reconoce la Nano 33 BLE; se parchea para aceptar cualquier nRF52840 (core mbed).
# Versión fijada para que el build sea reproducible.
set -euo pipefail

COMMIT=7948b85e020470a30a83bf00e10fc43b486bfcba
CLI="${ARDUINO_CLI:-$LOCALAPPDATA/Programs/Arduino IDE/resources/app/lib/backend/resources/arduino-cli.exe}"
LIBS="$("$CLI" config get directories.user | tr -d '\r')/libraries"
DEST="$LIBS/Arduino_TensorFlowLite"

if [ ! -d "$DEST/.git" ]; then
  git clone https://github.com/tensorflow/tflite-micro-arduino-examples "$DEST"
fi
if [ "$(git -C "$DEST" rev-parse HEAD)" != "$COMMIT" ]; then
  git -C "$DEST" fetch --depth 1 origin "$COMMIT"
  git -C "$DEST" checkout -q "$COMMIT"
fi
git -C "$DEST" checkout -q -- src   # parte de una copia limpia: el parche es idempotente

# Edita en el lugar (sin sed -i: OneDrive a veces bloquea el renombrado del archivo temporal).
patch_file() {
  local f="$DEST/$1" out
  out="$(sed "$2" "$f")"
  printf '%s\n' "$out" > "$f"
}
# La XIAO Sense es un nRF52840 con el mismo core mbed: que tome la rama de la Nano 33 BLE.
NRF='s/defined(ARDUINO_ARDUINO_NANO33BLE)/(defined(ARDUINO_ARDUINO_NANO33BLE) || defined(ARDUINO_ARCH_NRF52840))/'
patch_file src/peripherals/peripherals.h "$NRF"
patch_file src/tensorflow/lite/micro/system_setup.cpp "$NRF"
patch_file src/peripherals/peripherals.h 's/kLED_DEFAULT_GPIO = D13;/kLED_DEFAULT_GPIO = LED_BUILTIN;/'   # la XIAO no tiene D13
echo "Arduino_TensorFlowLite listo en $DEST ($COMMIT)"
