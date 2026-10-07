# SmartShoulder — 02. Especificaciones genéricas del firmware (Seeed XIAO nRF52840 Sense)

**Versión:** 0.1
**Relacionado:** `01-specs-app-paciente.md` (cliente BLE), `03-specs-modelo-tinyml.md` (modelo que corre aquí)

---

## 1. Hardware objetivo

| Elemento | Detalle |
|---|---|
| MCU | Nordic nRF52840 — ARM Cortex-M4F @ 64 MHz, FPU |
| Memoria | 1 MB Flash, 256 KB RAM, 2 MB QSPI flash externa |
| IMU | LSM6DS3TR-C (6 ejes: acelerómetro + giroscopio), I2C interno, dirección **0x6A** |
| Radio | Bluetooth 5.0 LE (+ NFC, sin uso por ahora) |
| Carga de batería | Chip BQ25101 integrado; batería en pads BAT+/BAT− |
| LEDs | RGB (ánodo común, **LOW = encendido**): rojo P0.26, verde P0.30, azul P0.06; LED de carga P0.17 |
| Tamaño | 21 × 17.8 mm |

### Pines de gestión de batería (importante)
- **P0.13**: corriente de carga. LOW = 100 mA, HIGH = 50 mA. Con una LiPo pequeña (≤ 200 mAh) usa **50 mA**; regla práctica: no cargar a más de ~1C.
- **P0.31 (AIN7)**: lectura de voltaje de batería por ADC.
- **P0.14 (READ_BAT_ENABLE)**: **mantenerlo en LOW** al leer el voltaje. Seeed advierte que con P0.14 en HIGH el pin P0.31 puede pasar de 3.6 V y dañarse.

## 2. Entorno de desarrollo

- **Arduino IDE 2.x** o **PlatformIO**.
- Paquete de placas: **"Seeed nRF52 mbed-enabled Boards"**. Seeed lo recomienda para IMU, PDM y machine learning embebido, y es el que funciona con los ejemplos de TensorFlow Lite.
  - El otro paquete ("Seeed nRF52 Boards", no mbed) consume menos energía y trae la librería Bluefruit; considéralo solo si después la autonomía se vuelve problema.
- Librerías:
  - `Seeed Arduino LSM6DS3` (IMU).
  - `ArduinoBLE` (BLE en el core mbed).
  - TensorFlow Lite Micro (`Chirale_TensorFlowLite` o la librería que exporte Edge Impulse; ver doc 03).

**Para desarrollar no hace falta soldar nada:** el IMU ya viene cableado por dentro y el USB-C da alimentación, programación y serial.

## 3. Modos de operación

| Modo | Para qué | Qué hace |
|---|---|---|
| `MODE_CAPTURE` | Construir el dataset | Lee el IMU a 50 Hz y transmite la señal cruda por BLE (o por serial USB). No corre el modelo. |
| `MODE_INFERENCE` | Uso real y demo | Lee el IMU, ventanea, corre el modelo, cuenta repeticiones y envía solo eventos. |

El modo se cambia con un comando BLE desde la app (o por serial, en desarrollo).

## 4. Máquina de estados

```
BOOT → IDLE_ADVERTISING ──(app conecta)──► CONNECTED_IDLE
                                              │
                         START_SESSION ───────┤
                                              ▼
                                       SESSION_ACTIVE ──(STOP / timeout)──► CONNECTED_IDLE
                                              │
                         (BLE perdido) ───────┤
                                              ▼
                                SESSION_ACTIVE_OFFLINE (sigue contando, guarda eventos en búfer)
                                              │
                                    (reconecta) → SYNC → SESSION_ACTIVE

Cualquier estado ──(batería < umbral)──► LOW_BATTERY (avisa a la app, LED rojo)
IDLE sin conexión por N min ──► SLEEP (advertising lento, IMU apagado)
```

## 5. Módulos del firmware

```
/src
  main.cpp            — loop principal, máquina de estados
  imu.cpp/.h          — init LSM6DS3, lectura a 50 Hz por timer, escalado
  ringbuffer.cpp/.h   — búfer circular de ventanas (6 canales × 100 muestras)
  preprocess.cpp/.h   — normalización y espejado izq/der (idéntico al de Python)
  inference.cpp/.h    — wrapper de TFLite Micro: arena, invoke(), softmax
  model_data.h        — modelo exportado como arreglo C
  repcounter.cpp/.h   — conteo de repeticiones (ver doc 03, sección 6)
  session.cpp/.h      — compara contra lo prescrito, acumula resultados
  ble_service.cpp/.h  — servicio GATT, characteristics, cola de eventos
  power.cpp/.h        — batería, carga, sleep
  config.h            — constantes (frecuencia, ventana, umbrales, UUIDs)
```

### 5.1 Adquisición del IMU
- **Frecuencia de muestreo: 50 Hz fija**, disparada por timer (no por `delay()`), para que el dataset y la inferencia tengan exactamente el mismo muestreo.
- ODR interno del sensor en 104 Hz; el firmware toma una muestra cada 20 ms.
- Rangos: acelerómetro ±4 g y giroscopio ±500 dps (suficiente para ejercicios de fisio; ajustar si se satura).
- Los **mismos rangos y escalas** se usan en captura y en inferencia. Si cambian, hay que reentrenar.

### 5.2 Preprocesamiento en el dispositivo
Debe ser **idéntico** al de Python (doc 03, sección 3). Cualquier diferencia rompe el modelo en silencio.
- Normalización con media y desviación estándar fijas, calculadas en el set de entrenamiento y copiadas a `config.h`.
- Si `arm == LEFT`, aplicar el espejado de ejes definido en doc 03.

### 5.3 Inferencia
- Ventana de 2 s (100 muestras), paso de 0.5 s (75 % de traslape). Ajustable en `config.h`.
- Entrada int8 cuantizada; tensor arena estimada de 32–64 KB (medir con `interpreter->arena_used_bytes()`).
- Suavizado: voto mayoritario sobre las últimas 3–5 ventanas antes de declarar `EXERCISE_CHANGED`.

## 6. Contrato BLE (servicio GATT)

UUIDs de 128 bits propios: generarlos una vez y fijarlos en `config.h` y en la app.

| Característica | Propiedades | Formato | Uso |
|---|---|---|---|
| `CONTROL` | Write | `[cmd:u8][payload…]` | START_SESSION, STOP_SESSION, SET_ARM, SET_MODE, SYNC_TIME, SYNC_EVENTS |
| `EVENTS` | Notify | struct de 12 bytes (abajo) | Repeticiones y cambios de ejercicio |
| `RAW_STREAM` | Notify | lote de N muestras int16 × 6 | Solo en `MODE_CAPTURE` |
| `STATUS` | Read/Notify | `[state:u8][mode:u8][arm:u8][fw_ver:u8]` | Estado del dispositivo |
| Battery Service (0x180F) | Read/Notify | % batería | Estándar BLE |

**Estructura de `EVENTS` (12 bytes, little-endian):**
```
uint8  type          // 1=REP, 2=EXERCISE_CHANGED, 3=SESSION_END
uint8  exercise_id   // ver catálogo en doc 05
uint16 rep_index
uint8  confidence    // 0–255 (= softmax × 255)
uint8  reserved
uint32 timestamp_ms  // desde START_SESSION
uint16 seq           // número de secuencia, para detectar pérdidas y sincronizar
```

**Ancho de banda del modo captura:** 6 canales × 2 bytes × 50 Hz = 600 B/s. BLE lo maneja sin problema si se agrupan ~10 muestras por notificación (120 bytes; negociar MTU ≥ 185).

## 7. Energía

- Uso típico: sesiones de 20–30 min al día; el resto del día en sleep.
- Batería sugerida: LiPo plana de 150–250 mAh (p. ej. formato 402030 o 502030) para que la carcasa no quede gruesa. Con eso alcanza para varios días de sesiones entre cargas (validar midiendo consumo real).
- Mediciones a hacer: corriente en sesión activa (IMU + inferencia + BLE) y en sleep.

## 8. Plan de desarrollo incremental

1. **Blink + serial:** confirmar toolchain y paquete mbed.
2. **IMU a 50 Hz por serial:** graficar en Serial Plotter, verificar ejes y que nada se sature.
3. **BLE básico:** advertising, conexión desde nRF Connect (app gratuita), característica `STATUS`.
4. **Modo captura por BLE:** `RAW_STREAM` → app → CSV. Con esto ya se puede empezar a grabar el dataset.
5. **Modelo dummy en TFLite Micro:** cargar un modelo trivial y medir arena y latencia.
6. **Modelo real + suavizado + contador de repeticiones.**
7. **Sesión completa:** START/STOP, búfer offline, SYNC.
8. **Energía:** sleep, lectura de batería y alerta de batería baja.
9. **Batería soldada + carcasa:** pruebas en la muñeca, sin cable.

## 9. Pruebas de verificación

- Mismo CSV procesado en Python y en el dispositivo (alimentado por serial) debe dar **las mismas predicciones**: prueba de paridad del preprocesamiento.
- Latencia de inferencia < 50 ms por ventana.
- Cero pérdidas de eventos en una sesión de 30 min (revisar `seq`).
- Desconectar y reconectar BLE a mitad de sesión: los eventos se recuperan completos.
