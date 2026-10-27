# Estado técnico del proyecto — Rumbo Rehab

**Fecha:** 27 oct 2026
**Alcance:** estado real de cada componente: qué funciona, qué está probado, con qué datos, y qué falta.
**Relacionado:** `07-plan-desarrollo-digital.md` (plan), `12-funcionalidades-app-y-web.md` (funciones), `contracts/ble.md` (protocolo)

---

## 1. Resumen

El sistema funciona **de punta a punta con hardware real**: reloj XIAO → app en Android → backend → dashboard del fisioterapeuta. Esta cadena se validó el 13 oct con el reloj RR-54F5 y un Galaxy A36: llegó una sesión **completa y verificada**.

Desde el 20 oct, el reloj lleva el **firmware v2** con un clasificador TinyML integrado. Está flasheado y corre en el dispositivo. **Aún no se prueba con movimiento real**; solo en reposo y en simulación.

La principal limitación es el **dataset: un solo participante (S01)**. El modelo y el contador funcionan bien con esa persona, pero **todavía no hay evidencia de que generalicen a otras personas**.

| Componente | Estado | Probado con |
|---|---|---|
| Firmware v2 (XIAO) | Flasheado; inferencia en el dispositivo funcionando | Reposo en el dispositivo; simulación con S01 |
| Modelo TinyML v1 | Entrenado y exportado (int8, 17 KB) | 1 sujeto, validación optimista |
| Contador de repeticiones | Calibrado por ejercicio | 1 sujeto (36 series) |
| Herramienta de captura | Funcional, con correcciones del 18 oct | 2 grabaciones completas |
| App del paciente (Flutter) | Funcional, con marca y upgrade | A36 de punta a punta (13 oct) |
| Backend (NestJS) | Funcional | Pruebas unitarias + smoke test |
| Dashboard (Next.js) | Funcional, con marca | Validado en navegador (13 oct) |

---

## 2. Arquitectura

```
Reloj (XIAO nRF52840 Sense)          App del paciente (Flutter, Android)       Backend (NestJS + Prisma + PostgreSQL)
  IMU 6 ejes a 50 Hz                   guía la sesión, envía SET_EXPECTED        sesiones, apego, planes
  contador + CNN int8 (TFLM)  ──BLE──▶ recibe eventos REP                ──HTTP──▶  cálculo verificado vs reportado
  decide si cada repetición            sube la sesión (cola sin internet)                    │
  es del ejercicio esperado                                                                   ▼
                                                                          Dashboard del fisio (Next.js)
```

Principio de diseño: **la app no procesa señal**. El reloj cuenta y verifica; la app solo le dice qué ejercicio toca y registra lo que el reloj reporta. El apego **verificado** (lo que contó el reloj) y el **reportado** (lo que declara el paciente) se guardan y se muestran siempre por separado.

---

## 3. Hardware

- **Placa:** Seeed XIAO nRF52840 Sense (IMU LSM6DS3TR-C), en carcasa impresa con correa y pila LiPo soldada. Reloj de pruebas: **RR-54F5**.
- **Colocación** (regla fija desde el 18 oct): flecha ▲ hacia el pulgar, conector USB-C del lado del pulgar, en ambas muñecas.
- **Energía:**
  - Apagado por software (System OFF), con tres disparadores: comando, 15 min sin uso o batería crítica (< 3.35 V).
  - Se enciende al conectar el USB-C o con reset.
  - Carga a 50 mA.
- ⚠️ **Problema abierto: la pila no sube de voltaje al cargar.** El 27 oct medía 3.09 V con el USB conectado, sin cambio en 100 s. El LED verde de carga estaba encendido. Hipótesis:
  - sobre-descarga, con una recuperación lenta del cargador;
  - pila dañada;
  - soldadura floja.

  Pendiente: medirla después de un rato de carga y revisarla con multímetro. El medidor de batería tampoco está calibrado (`VBAT_CAL = 1.0`).

---

## 4. Firmware (`firmware/rumbo`)

**Versión actual: FW_VERSION 3 ("v2"), MODEL_VERSION 1.** Core mbed de Seeed 2.9.3, ArduinoBLE 2.0.2 y TensorFlow Lite Micro.

### 4.1 Qué hace
- **Modo captura:** transmite la señal cruda por BLE o por USB serial (para el dataset).
- **Modo inferencia:** guarda una ventana de 2 s, ya espejada y cuantizada, y corre la CNN cada 0.5 s.
- **Verificación:** el contador detecta una repetición, y solo se emite el evento `REP` si el modelo vio el ejercicio esperado durante esa repetición. La confianza del evento es la probabilidad media de la clase esperada en esas ventanas.
- **Robustez:** guarda en el reloj los últimos 256 eventos para reenviarlos si se pierde la conexión (`SYNC_EVENTS`).

### 4.2 Medido en el dispositivo (20 oct)
| Métrica | Valor |
|---|---|
| Tiempo por inferencia | 36–44 ms (cada 500 ms) |
| Muestras perdidas | 0 |
| RAM usada | 42 % (100 KB de 237 KB) |
| Reposo | NULO con 98 % de confianza |

### 4.3 Dependencia externa
TensorFlow Lite Micro oficial (`tflite-micro-arduino-examples`) **solo reconoce la Nano 33 BLE**. `firmware/setup_tflm.sh` lo instala fijado a un commit concreto y lo parchea para cualquier nRF52840 con core mbed. Hay que correrlo una vez en cada PC que compile el firmware.

---

## 5. Modelo TinyML (`ml/rumbo_ml`)

### 5.1 Arquitectura y exportación
- **Modelo:** CNN 1D (Conv2D de alto 1) de 3 capas convolucionales; **9,527 parámetros**.
- **Exportación:** int8 completo con TFLite, **17 KB**. La versión int8 coincide con la de punto flotante en el **99.6 %** de las ventanas.
- **Ventanas:** 2 s (100 muestras), con paso de 0.5 s; la etiqueta es la del ejercicio si cubre ≥ 80 % de la ventana.
- **Preprocesamiento:**
  - espejado del brazo izquierdo en el **eje Y** (confirmado el 18 oct);
  - normalización z-score;
  - cuantización.

  Es idéntico en Python y en el firmware: las constantes salen de `model_config.h`.
- **Aumentación:** rotación ±10°, estiramiento en el tiempo ±15 %, escala ±10 % y ruido.

### 5.2 Decisión: rotación externa e interna comparten clase
Las dos rotaciones recorren **el mismo arco sobre el eje vertical**; solo cambia el lado donde está anclada la banda. La gravedad se ve igual y el reloj no puede distinguirlas: se confundían ~35 %. El modelo verifica "rotación", y la app indica cuál de las dos toca. Está configurado en `config.CLASS_MERGE` y se exporta como `MODEL_CLASS_OF`.

### 5.3 Resultados (solo S01, 48 min, ambos brazos)
| Validación | Accuracy | F1 macro |
|---|---|---|
| Dejar fuera un ritmo (lento / normal / rápido) | 0.90 | 0.93 |
| Entrenar con un brazo, probar con el otro | 0.74 | 0.72 |

Casi todos los errores son "no detectó el ejercicio" (lo predice como NULO), no "confundió el ejercicio".

> **Límite importante:** con un solo sujeto no se puede hacer *leave-one-subject-out*. Estas métricas son **optimistas**: prueban a la misma persona con la que se entrenó. La meta del documento 03 (F1 ≥ 0.90 bajo LOSO) **sigue sin evaluarse**.

---

## 6. Contador de repeticiones

- **Algoritmo:** máquina de estados con histéresis sobre la señal filtrada (ida y vuelta en el eje dominante).
- **Paridad:** el código en Python es copia exacta del de C. La paridad se verificó contra una captura real del dispositivo (`ml/tests/data/paridad_flexion_xiao.csv`).
- **Umbrales por ejercicio**, calibrados el 20 oct con `python -m rumbo_ml.calibrate`. La **estabilización escapular** casi no gira, así que se cuenta con el **acelerómetro sin gravedad**; los demás ejercicios, con el giroscopio.

### Simulación del firmware completo sobre S01 (`python -m rumbo_ml.verify --model 1 --wrong`)
| Métrica | v1.1 (sin modelo) | v2 |
|---|---|---|
| Error medio por serie | 1.39 reps | **0.58 reps** |
| Series exactas | 44 % | 67 % |
| Series dentro de ±1 | 75 % | **89 %** |
| Repeticiones de un ejercicio equivocado aceptadas | (contaba todo) | **0 de 1,510** |
| Repeticiones correctas rechazadas | — | 0 |

Errores restantes:
- Algunas series de rotación interna y de tríceps cuentan 12–13 de 10.
- Una serie de escapular cuenta 15.

Igual que en el modelo, la simulación usa los datos de entrenamiento: **prueba la lógica, no la generalización**.

---

## 7. Dataset

| Sujeto | Brazo | Duración | Muestras perdidas | Protocolo |
|---|---|---|---|---|
| S01 | Derecho | 24.8 min | 0 | Completo: 6 ejercicios × 3 ritmos, más NULO |
| S01 | Izquierdo | 22.8 min | 4 | Completo |

- **Meta:** 15–20 voluntarios sanos (el paper de referencia usó 20). **No se ha grabado a nadie más.**
- **Control de calidad:**
  - muestras perdidas;
  - saturación;
  - protocolo completo;
  - orientación del reloj, comparando la gravedad con el brazo colgando (alerta si se desvía más de 25°).
- **Privacidad:** `dataset/` nunca se sube al repositorio.
- **Dataset público:** se evaluó **SPARS9x** (paper MDPI, Huawei Watch 2, 20 sujetos). Comparte solo 3–4 ejercicios con el protocolo, varios son isométricos, el sensor es otro y el acceso a IEEE DataPort es restringido. Por ahora no se usa.

---

## 8. Herramienta de captura (`tools/capture`)

Python, con Tkinter, bleak y pyserial; captura por BLE o por USB.

**Correcciones del 18 oct:**
- La barra espaciadora disparaba dos veces. Era la causa de las primeras grabaciones malas, ya descartadas.
- No se cierran series de menos de 5 s.
- Pide confirmación al detener y pregunta "¿misma persona?".
- Nuevo botón "Apagar reloj".

Guía de uso: `13-guia-captura-dataset.md`.

---

## 9. App del paciente (`app/`)

- **Plataforma:** Flutter 3.27, `mx.rumborehab.app`, Android minSdk 24. BLE con `flutter_reactive_ble` (licencia BSD).
- **Flujo:** bienvenida → privacidad → emparejamiento con el reloj → sesión guiada → resumen con escala de dolor → historial.
- **Sesión:**
  - le indica al reloj el ejercicio de cada serie;
  - pulso, vibración y sonido por repetición;
  - descanso guiado;
  - aviso si el reloj se desconecta.
- **Meta semanal**, en lugar de racha diaria.
- **Sin internet:** cola de sesiones pendientes de subir.
- **Reloj simulado** (plan B de la demo): en Ajustes, tocar 5 veces el título.
- **Pendiente:**
  - integrar los 7 videos de ejercicios;
  - rehacer la APK con la ilustración de colocación hacia el pulgar (cambiada el 18 oct, sin revisión visual);
  - revisión de accesibilidad en el A36 (letra al 130 %, TalkBack);
  - prueba con usuarios.

## 10. Backend (`api/`) y dashboard (`web/`)

- **Backend:** NestJS, Prisma y PostgreSQL (Docker `rumbo-db`, puerto 5434; API en 3001).
  - Cálculo de apego en funciones puras con pruebas: una sesión es completa con ≥ 90 % de las repeticiones de cada ejercicio.
  - Verificado y reportado se manejan siempre por separado.
- **Dashboard:** Next.js 16 (puerto 3000).
  - Pacientes, calendario de apego, KPIs de la clínica y flota de relojes.
  - Íconos distintos para verificado y reportado.
- **Datos demo:** `fisio@demo.mx` / `demo1234`; código de paciente `DEMO23` (reloj RR-54F5). Hay que volver a cargarlos antes de la entrega.

---

## 11. Riesgos y pendientes

### Riesgos
| Riesgo | Impacto | Mitigación |
|---|---|---|
| Un solo participante en el dataset | No hay evidencia de que funcione con otras personas | Grabar 3–5 voluntarios como mínimo para medir LOSO; en la demo, la persona del dataset usa el reloj |
| Pila que no carga | El reloj solo funciona conectado al USB | Diagnóstico pendiente; cambiar la pila si no recupera |
| Firmware v2 sin probar con movimiento | Fallas no vistas en simulación | Prueba en vivo por serial y luego con la app |
| Rotaciones no distinguibles | El reloj verifica "rotación", no cuál de las dos | Decisión documentada; la app indica cuál |
| Librería TFLM parcheada | Build frágil en otra PC | Script fijado a un commit concreto (`setup_tflm.sh`) |

### Pendientes, en orden de prioridad
1. Diagnosticar la pila.
2. Prueba en vivo del firmware v2: repeticiones correctas, y la "trampa" de hacer otro ejercicio para ver que no cuente. Luego, de punta a punta con la app y el dashboard.
3. **Commit** del trabajo desde el 18 oct: firmware v2, modelo, calibración, herramienta de captura, QC y documentación.
4. Grabar voluntarios y reentrenar con validación LOSO real.
5. App: videos, APK con la nueva ilustración, accesibilidad.
6. Volver a cargar los datos demo y ensayar la demo, incluido el plan B con el reloj simulado.

---

## 12. Cómo reproducir

```
# Firmware (una vez: bash firmware/setup_tflm.sh)
arduino-cli compile --fqbn Seeeduino:mbed:xiaonRF52840Sense --upload -p COM5 firmware/rumbo

# Modelo
cd ml
python -m rumbo_ml.train --model cnn --holdout speed --export 1 --to-firmware
python -m rumbo_ml.calibrate
python -m rumbo_ml.verify --model 1 --wrong
python -m pytest -q          # 25 pruebas

# Plataforma: ver README.md (Docker + api + web + app)
```
