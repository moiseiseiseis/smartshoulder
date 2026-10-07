# SmartShoulder — 07. Plan de desarrollo digital (firmware XIAO, app del paciente, web del fisio)

**Versión:** 0.1 (6 oct 2026)
**Relacionado:** todos los docs 01–06 y `app.md` (benchmark de Avena y modelo de negocio)

**Supuestos** (ajustar si no se cumplen):
- Equipo de 1–2 personas de desarrollo, con apoyo de IA para el código de app, web y backend.
- Demo Day en ~10 semanas. El plan está en semanas relativas (S1 = semana del 12 oct); si la fecha real es otra, se comprimen o estiran las fases 3–5, **no** la ruta crítica (fases 1–2).
- Se reutiliza lo que sirva de SmartKnee (UI kit web, auth JWT, esquema de backend).

---

## Actualización 6 oct 2026 — calendario real y estado

**Demo Day: 23 de octubre** (17 días). El calendario de 10 semanas de la sección 3 queda reemplazado por este:

| Fechas | Ruta crítica (dato → modelo) | Software | Estado |
|---|---|---|---|
| 6 oct | Firmware de captura v1 + herramienta de captura | Backend, dashboard web y app Flutter (etapas 1–3) | ✅ Hecho |
| 7–8 oct | Carcasa terminada y LiPo soldada; prueba de autonomía | — | Pendiente (Moisés) |
| 8–11 oct | **Grabar 15–20 participantes** (QC tras cada uno) | Ajustes de UX en la app | Pendiente |
| 11–14 oct | Modelo: baseline → CNN; si al 14 no llega a F1 ≥ 0.90, Edge Impulse | Reloj real en la app (sin modelo aún) | Pendiente |
| 14–17 oct | Firmware v2: inferencia + contador + `SET_EXPECTED` + búfer y `SYNC` | Despliegue de la API y la web | Pendiente |
| 18–20 oct | Integración de punta a punta con el reloj real; pruebas con 3–5 personas | Correcciones | Pendiente |
| 21–22 oct | **Congelar** firmware, modelo y apps; ensayo ×5; video de respaldo | Re-sembrar datos demo la mañana del 23 | Pendiente |

**Decisiones tomadas (6 oct):**
- Proyecto nuevo desde cero (no se reutiliza SmartKnee).
- La captura del dataset vive solo en Python (`tools/capture`), fuera de la app del paciente.
- La app usa **flutter_reactive_ble** (BSD-3) en lugar de flutter_blue_plus: la 2.x de flutter_blue_plus exige licencia de pago para uso comercial y manda telemetría al compilar.
- Driver propio del IMU en el firmware: la librería de Seeed 2.0.5 no compila con el core mbed.
- `START_SESSION` lleva el tamaño de lote de `RAW_STREAM`, porque ArduinoBLE no expone el MTU negociado.

**Verificado en hardware (6 oct):** captura por USB y por BLE desde la PC a 50.01 Hz, con 0 muestras perdidas en 3 minutos (MTU 247, 8 muestras por paquete).

---

## 0. Resumen en 6 puntos

1. **La ruta crítica es el dato, no el software.** Montaje en muñeca → firmware de captura → dataset de 15–20 sujetos → modelo → modelo dentro de la XIAO. Son ~7 semanas mínimas y nada de la app ni de la web las acelera. Todo lo demás se construye **en paralelo** contra un simulador.
2. **Contratos primero.** El contrato BLE y el contrato REST se fijan en la semana 1, en un solo lugar del repo, y de ahí salen las constantes para C, Dart, Python y TypeScript. Es lo que permite trabajar en paralelo sin romper nada.
3. **Simulador de dispositivo desde el día 1.** La app y el dashboard se desarrollan sin el reloj; el simulador también es el **plan B en el escenario** si el Bluetooth falla en la demo.
4. **El modo investigador sale de la app del paciente.** La captura del dataset se hace con una herramienta de escritorio en Python (`bleak`). Desbloquea el dataset 2–3 semanas antes, simplifica la app y deja el código de investigación fuera del producto regulado.
5. **La UX de la sesión es manos libres.** El paciente está haciendo ejercicio con el brazo afectado y el teléfono queda sobre una mesa: contador gigante, conteo por voz, avance automático entre series. Es la pantalla que más importa del producto.
6. **La demo cuenta una sola historia: "reportado vs. verificado".** Cada pantalla que se construya debe ayudar a contar esa historia; lo que no ayude (agenda, chat, cobros, PDF formateado) queda fuera hasta el piloto.

---

## 1. Diagnóstico de las specs actuales

### 1.1 Lo que está bien resuelto
- Separación clara de tareas del modelo (clasificar con ML, contar con señal) y clase `NULO` obligatoria.
- Postura regulatoria consistente en todos los docs: medir apego, nunca evaluar calidad clínica ni recomendar.
- Definición explícita y auditable de adherencia (doc 04, 5.3).
- Plan incremental del firmware (doc 02, sección 8) y prueba de paridad Python ↔ dispositivo.
- Modelo de negocio con la capa software separada del add-on de hardware (`app.md`, 6.4).

### 1.2 Huecos e inconsistencias a corregir antes de programar

| # | Dónde | Problema | Propuesta |
|---|---|---|---|
| 1 | Doc 02 §6 vs doc 03 §8 | Doc 03 dice que el firmware reporta la versión del modelo en `STATUS`, pero `STATUS` solo tiene `fw_ver` | `STATUS` = `[state][mode][arm][fw_ver][model_ver]` (5 bytes) |
| 2 | Doc 02 §5 (`session.cpp`) vs doc 04 §5.3 | La lógica de "sesión completa" aparece en el firmware **y** en el backend | El firmware **solo reconoce y cuenta**. La app maneja el flujo (ejercicio actual, serie, descanso) y el backend calcula completa/incompleta. Una sola fuente de verdad, y el firmware queda más simple |
| 3 | Doc 01 §4.3 / doc 02 | No está definido quién marca el inicio y fin de cada serie | La app manda `SET_EXPECTED(exercise_id)` al iniciar cada serie; el dispositivo cuenta solo si el clasificador coincide con lo esperado. Agregar ese comando a `CONTROL` |
| 4 | Doc 01 §7, doc 04 §5.1 | Faltan `ProtocolTemplate`, `source: verified \| reported` en `Session` y el ciclo de vida del dispositivo (asignado → devuelto → limpio) | Ya lo pide `app.md` §7; se incluye en el esquema de la sección 4.5 de este doc |
| 5 | Doc 01 §6 | El modo investigador vive en la app del paciente | Herramienta de captura en Python, fuera de la app (sección 4.2) |
| 6 | Doc 05 §3 vs doc 06 §6 | La captura del dataset (archivo de ejemplo del 10 oct) puede empezar antes de tener carcasa | El dataset debe grabarse con la **misma orientación de placa** que tendrá la carcasa final. Mínimo: un soporte provisional impreso con el tope de orientación (R1) antes del primer sujeto |
| 7 | Doc 02 §6 | El modo captura supone MTU ≥ 185; con `ArduinoBLE` sobre el core mbed el MTU efectivo puede quedar más bajo | Medirlo en S1. Si no alcanza: lotes más chicos por notificación, o captura por USB serial con cable largo como respaldo |
| 8 | `app.md` §5 vs §6.4 | Hay dos tablas de precios | La 6.4 (software + add-on) reemplaza a la 5; marcar la 5 como superada |
| 9 | Doc 01 §4.1 | El emparejamiento lo hace el paciente en casa | Se hace **en consulta**, con el fisio (sección 5.2). Menos soporte técnico y cuadra con "el nodo es flota de la clínica" |

---

## 2. Decisiones de arquitectura

### 2.1 Estructura del repositorio (monorepo)

```
SmartShoulder/
  contexto/            ← docs 01–07 (ya existe)
  contracts/           ← FUENTE ÚNICA de verdad de los contratos
    ble.yaml             UUIDs, comandos, structs, catálogo de exercise_id
    gen/                 script que genera: config_ble.h (C), ble_contract.dart, ble_contract.py
    openapi.yaml         generado por NestJS; de ahí sale el cliente TS y el de Dart
  firmware/            ← PlatformIO, XIAO nRF52840 Sense (core mbed)
  ml/                  ← Python: dataset, entrenamiento, exportación, prueba de paridad
  tools/
    capture/             app de escritorio de captura (Python + bleak)
    simulator/           simulador del dispositivo (para app y demo)
    seed/                generador de pacientes demo con historial
  app/                 ← Flutter (paciente)
  api/                 ← NestJS + Prisma + PostgreSQL
  web/                 ← Next.js (fisio y admin de clínica)
  hardware/            ← archivos de Fusion, STL/3MF, fotos de medición
```

Un solo repo con git desde hoy (ahora mismo la carpeta no está versionada). Es lo que permite que un cambio de contrato BLE toque firmware, app y herramienta de captura en el mismo commit.

### 2.2 Vista general

```
   ┌──────────────── XIAO (muñeca) ────────────────┐
   │ IMU 50 Hz → ventana 2 s → CNN int8 → voto     │
   │           → contador de picos → EVENTS (BLE)  │
   └──────────────────────┬────────────────────────┘
                          │ BLE (contrato en contracts/ble.yaml)
        ┌─────────────────┴──────────────────┐
        ▼                                    ▼
 App Flutter (paciente)            tools/capture (Python, solo investigación)
 flujo de sesión, voz, SQLite            CSV crudo + etiquetas → ml/
        │ HTTPS (cola offline)
        ▼
 API NestJS ── PostgreSQL ──  módulo "apego" (regulado)  |  módulo "gestión" (no regulado)
        ▲
        │ HTTPS
 Web Next.js (fisio / admin de clínica)
```

### 2.3 Reglas que se aplican en todo el código

| Regla | Por qué |
|---|---|
| **Módulos separados en el backend:** `adherence` (sesiones, eventos, cálculo de apego, reportes) vs. `management` (clínicas, usuarios, flota, plantillas) | Aplica en código la regla regulatoria de `app.md` §4: lo administrativo no amplía el alcance del dispositivo médico |
| **`source` en todo dato de apego** (`verified` / `reported`), y nunca se suman en el mismo indicador | Es el diferenciador del producto y un requisito de claridad regulatoria |
| **Toda sesión guarda `fwVersion` y `modelVersion`** | Trazabilidad ISO 14971 (doc 03 §8) |
| **El cálculo de apego vive solo en el backend**, con pruebas unitarias contra casos escritos a mano | Definición auditable; la app y la web solo lo muestran |
| **Offline-first en la app:** la sesión se guarda en SQLite y se sube con reintentos e idempotencia (`clientSessionId`) | El paciente puede no tener datos; nunca se pierde ni se duplica una sesión |
| **Datos demo marcados en la base** (`isDemo = true`) y con una etiqueta visible en la web | Doc 04 §7: que el jurado nunca confunda simulación con dato real |

---

## 3. Ruta crítica y fases

### 3.1 Ruta crítica (lo que define la fecha)

```
S1 Montaje provisional + firmware captura ─► S2 Herramienta de captura + 2 sujetos piloto (QC)
   ─► S3–S4 Dataset completo (15–20 sujetos)  ─► S4–S5 Modelo baseline/CNN (LOSO)
   ─► S5–S6 Modelo + contador en la XIAO (paridad)  ─► S7–S8 Integración real con la app
   ─► S9 Pruebas de campo  ─► S10 Congelar y ensayar demo
```

Si la agenda de voluntarios se retrasa una semana, Demo Day se retrasa una semana. **Agendar a los voluntarios es la primera tarea de negocio, no de código.**

### 3.2 Fases

| Fase | Semanas | Firmware / ML | App Flutter | API + Web | Negocio / UX | Criterio de salida |
|---|---|---|---|---|---|---|
| **0. Fundaciones** | S1 | Pasos 1–3 de doc 02 (blink, IMU 50 Hz, BLE `STATUS`). Medir MTU real | Proyecto creado, navegación y tema | Repo, Prisma schema, auth, deploy vacío en Railway/Render con HTTPS | Reunión con el fisio: ejercicios, plantillas, precios (sección 6.1). Agendar voluntarios. Wireframes de baja fidelidad | `contracts/ble.yaml` v1 congelado; XIAO conectada desde nRF Connect |
| **1. Captura** | S2 | `MODE_CAPTURE` por BLE. Soporte provisional con orientación fija. `tools/capture` | Simulador BLE + pantallas de sesión contra el simulador | CRUD de pacientes, plantillas, prescripción | Pruebas de los wireframes con el fisio (15 min) | 2 sujetos piloto grabados y revisados con el QC de doc 05 §3.4 |
| **2. Dataset y modelo** | S3–S5 | 15–20 sujetos. Baseline A y CNN B; Edge Impulse como atajo si B se atrasa | Onboarding por QR, home, resumen, historial, cola offline | `POST /sessions`, cálculo de apego con pruebas, lista de pacientes con alertas, detalle | Diseño visual (alta fidelidad) de las 4 pantallas clave | F1 macro LOSO ≥ 0.90 o decisión documentada de quitar un ejercicio |
| **3. En el dispositivo** | S5–S6 | Exportación int8, inferencia, voto, contador, `SET_EXPECTED`, prueba de paridad | Conteo por voz, avance automático, batería | Gestión de flota (asignar / devolver), KPIs de clínica | Guion de la demo v1 | Latencia < 50 ms por ventana; paridad Python = XIAO en el mismo CSV |
| **4. Integración real** | S7–S8 | Búfer offline + `SYNC_EVENTS`, sleep, batería baja. Carcasa v2 en PETG | App con reloj real de punta a punta | Seed de 2–3 pacientes demo con 6 semanas de historial; export CSV | Prueba con 3–5 usuarios reales (ideal: un adulto mayor) | Sesión de 30 min sin pérdida de eventos (`seq`); desconexión y reconexión recuperan todo |
| **5. Endurecer y demo** | S9–S10 | Congelar firmware y modelo (versión etiquetada) | Congelar; build release firmado | Congelar; respaldo de la base | Ensayo cronometrado ×5, video de respaldo, pitch | Demo completa 5 veces seguidas sin fallar |

---

## 4. Plan por componente

### 4.1 Firmware XIAO (doc 02)

Se mantiene el plan de doc 02 con estos cambios:

- **PlatformIO** en lugar de Arduino IDE: carpetas de doc 02 §5 tal cual, pruebas nativas del preprocesamiento y del contador (`pio test -e native`) sin hardware.
- **`config_ble.h` generado** desde `contracts/ble.yaml`; nunca se edita a mano.
- **`session.cpp` se reduce** a: ejercicio esperado actual, contador por serie y búfer de eventos con `seq`. El juicio de completa/incompleta se va al backend (hallazgo #2).
- **Comandos de `CONTROL`:** `START_SESSION`, `SET_EXPECTED`, `STOP_SESSION`, `SET_ARM`, `SET_MODE`, `SYNC_TIME`, `SYNC_EVENTS`, más `IDENTIFY` (parpadeo del LED para que el fisio sepa qué reloj está emparejando cuando tiene varios sobre la mesa).
- **Identidad del nodo:** un número corto legible (`SS-014`) derivado de la MAC, impreso en la carcasa y anunciado en el nombre BLE. Es lo que el fisio ve en el dashboard; nadie debería ver una MAC.
- **Riesgo de energía del core mbed:** se mide en la fase 4. Si la autonomía no alcanza para una semana de sesiones, se documenta "cargar cada X días" para Demo Day y la migración al core no-mbed queda para el piloto.
- **OTA (DFU por BLE):** fuera de Demo Day. Las actualizaciones se hacen por USB.

### 4.2 ML y herramienta de captura (docs 03 y 05)

- **`tools/capture` (Python + `bleak` + una UI mínima en terminal o Tkinter):** selecciona sujeto, brazo y ejercicio; barra espaciadora = inicio/fin de serie; tecla `R` = marca de repetición; escribe `raw/` y `labels/` con el formato exacto de doc 05 §3.5 y grafica la serie al terminar para el QC. Corre en la laptop del investigador, que es donde se trabaja durante la captura.
- **`ml/`:** notebooks solo para explorar; el pipeline vive en módulos (`preprocess.py`, `windows.py`, `train.py`, `export.py`, `parity.py`). `preprocess.py` y `preprocess.cpp` comparten las constantes generadas desde un mismo archivo.
- **Versionado del modelo** según doc 03 §8: cada exportación escribe un `model_card.json` (versión, hash del dataset, sujetos, constantes, métricas LOSO, commit).
- **Atajo con decisión fija:** si al final de S4 la CNN propia no llega a la meta, se usa Edge Impulse para Demo Day sin discutirlo más. La meta es la demo, no la elegancia del pipeline.

### 4.3 App del paciente (Flutter, doc 01)

**Stack:** el de doc 01 + `wakelock_plus` (pantalla encendida durante la sesión), `flutter_tts` (voz en español), `mobile_scanner` (QR), `drift` o `sqflite` (cola offline), `go_router`. Estado con lo mismo que SmartKnee.

**Arquitectura interna:**
```
lib/
  core/ble/          DeviceClient (interfaz) ← RealDevice (flutter_blue_plus) | SimulatedDevice
  core/contract/     generado desde contracts/ble.yaml
  core/sync/         cola de sesiones con reintentos e idempotencia
  features/onboarding · home · session · summary · history · settings
```
`SimulatedDevice` emite eventos `REP` con ritmo realista y permite forzar desconexiones. Se activa con un gesto oculto en la pantalla de ajustes (plan B de la demo).

**Alcance Demo Day:** Android; onboarding por QR; sesión con reloj (verificada) y sin reloj (reportada); resumen con dolor y esfuerzo; historial con calendario; recordatorio diario. iOS, gamificación y videos profesionales quedan después (videos grabados con el celular por el fisio son suficientes).

### 4.4 Web del fisio (Next.js, doc 04)

- **Stack:** Next.js (App Router) + TypeScript, UI kit de SmartKnee, TanStack Table para la lista, Recharts para gráficas, cliente generado desde `openapi.yaml`.
- **Pantallas Demo Day (en orden de importancia):**
  1. **Pacientes**: lista ordenada por peor apego, con alertas (sección 5.3).
  2. **Detalle del paciente**: calendario, reps hechas vs. prescritas, ejercicio que más se salta, dolor reportado, badge verificado/reportado.
  3. **Nuevo paciente → prescripción desde plantilla → asignar reloj → QR de invitación**, en un solo flujo de 3 pasos.
  4. **Clínica**: pacientes activos, apego promedio (separado verificado / reportado), sesiones verificadas de la semana, relojes en uso / disponibles / en limpieza.
- **Actualización "en vivo" para la demo:** refrescar el detalle del paciente cada 5 s (polling). No hace falta WebSocket.
- **Fuera de Demo Day:** PDF con formato clínico (el CSV basta), multi-clínica completo, agenda, chat, cobros, directorio.

### 4.5 Backend (NestJS + Prisma + PostgreSQL)

Esquema consolidado (docs 01, 04 y `app.md` §7):

```
Clinic(id, name, logoUrl?)
User(id, clinicId, role: physio|clinic_admin|patient, email, passwordHash)
Patient(id, clinicId, physioId, userId?, displayName, affectedArm, diagnosisText, isDemo)
InviteCode(code, patientId, expiresAt, usedAt?)
ProtocolTemplate(id, clinicId?, name, weeks, items[])            ← nuevo
Prescription(id, patientId, templateId?, frequencyPerWeek, startDate, endDate, notes, version)
PrescriptionItem(prescriptionId, exerciseId, sets, reps, restSec)
ExerciseCatalog(id = exercise_id, name, instructions, videoUrl, enabled)
Device(id, clinicId, bleName, shortCode, status: available|assigned|cleaning|retired, fwVersion, modelVersion, lastBattery, lastSeenAt)
DeviceAssignment(deviceId, patientId, assignedAt, returnedAt?)  ← historial de la flota
Session(id, clientSessionId UNIQUE, patientId, prescriptionId, source: verified|reported,
        deviceId?, fwVersion?, modelVersion?, startedAt, endedAt, status, painScore?, effortScore?)
SessionExerciseResult(sessionId, exerciseId, setsDone, repsDone, repsPrescribed)
SessionEvent(sessionId, seq, type, exerciseId, repIndex, confidence, deviceTimestampMs)
AuditLog(actorId, action, entity, entityId, diff, at)
```

Endpoints: los de doc 04 §5.2 más `POST /invites/:code/redeem`, `GET /clinic/kpis`, `PATCH /devices/:id/status` y `GET /patients/:id/sessions?source=`. Swagger activo para generar los clientes.

---

## 5. UX y UI

### 5.1 Principios

| Principio | Cómo se ve en el producto |
|---|---|
| **El fisio configura, el paciente solo ejecuta** | Todo lo difícil (emparejar, elegir brazo, prescribir) pasa en consulta. En casa, el paciente abre la app y toca un solo botón |
| **Manos libres durante la sesión** | El teléfono está sobre la mesa a 1–2 m y el paciente tiene el brazo ocupado: voz, contador legible a distancia, avance automático |
| **Verificado ≠ reportado, siempre visible** | Mismo ícono + color + texto en app y web. Nunca solo color (daltonismo) |
| **Lenguaje de acompañamiento, no de error** | "¿Estás haciendo abducción?" en lugar de "Ejercicio incorrecto". El sistema nunca regaña |
| **Menos formularios que Avena** | Su queja principal son los formularios largos: alta de paciente con 3 campos obligatorios (nombre, brazo, diagnóstico en texto libre) |
| **Accesible para adultos mayores** | Texto base ≥ 18 sp, botones ≥ 56 dp, contraste AA, una sola acción principal por pantalla |

### 5.2 Flujos clave

**En consulta (una sola vez, ~3 min, lo guía el fisio):**
1. Web: Nuevo paciente → elegir plantilla → asignar reloj `SS-014` → aparece un QR.
2. El paciente instala la app y escanea el QR. El QR lleva el código de invitación **y** el reloj asignado, así que la app ya sabe con qué dispositivo emparejar.
3. La app busca el reloj; el fisio toca "Identificar" y el LED del reloj correcto parpadea.
4. Aviso de privacidad y consentimiento (LFPDPPP), en lenguaje simple.
5. Primera serie de práctica en consulta: el paciente ve el contador subir frente al fisio. Este es el momento "ajá" del producto.

**En casa (cada día):**
1. Notificación → abre la app → **"Comenzar sesión"** (un solo botón; el estado del reloj y la batería se ven abajo).
2. "Coloca el teléfono donde puedas verlo" → cuenta regresiva por voz.
3. Por cada serie: la voz dice el ejercicio, el contador sube con un sonido por repetición, y al llegar a la meta empieza solo el descanso con cuenta regresiva.
4. Resumen: lo hecho vs. lo prescrito, en lenguaje positivo. Dolor 0–10 con caritas, un toque. Listo.
5. Sin internet: "Guardado. Se enviará a tu fisioterapeuta cuando tengas conexión."

### 5.3 Pantallas clave

**App — Sesión en curso** (la pantalla más importante del producto):
```
┌───────────────────────────────┐
│ Rotación externa   Serie 2 / 3│
│                               │
│            7                  │  ← número de 140 sp, legible a 2 m
│          de 12                │
│                               │
│ ●●●●●●●○○○○○                  │  ← progreso de la serie
│ [video en bucle, sin sonido]  │
│ ✓ Reloj detectando tu ejercicio│  ← o el aviso suave si no coincide
│                               │
│   [ Pausa ]      [ Terminar ] │
└───────────────────────────────┘
```

**Web — Lista de pacientes** (pantalla de entrada del fisio): la pregunta que responde es *"¿a quién tengo que llamar hoy?"*.
```
Pacientes (12 activos)          [ + Nuevo paciente ]
Filtro: Todos | Con alerta (3) | Con reloj | Sin reloj
─────────────────────────────────────────────────────────────────
⚠ María G.   Manguito rot. sem 3   38% ▼   ⌚ Verificado   Sin sesión hace 4 días
⚠ Juan P.    Tendinopatía sem 5    45%     ✋ Reportado     Apego < 50% esta semana
  Ana L.     Post-qx sem 2         92%     ⌚ Verificado   Hoy
```

### 5.4 Sistema visual compartido

Un solo archivo de tokens (`contracts/design-tokens.json`) que se usa en Flutter y en la web: colores, tipografía, radios y, sobre todo, los dos estados de apego:
- **Verificado:** ícono de reloj + "Verificado por el dispositivo".
- **Reportado:** ícono de mano + "Reportado por el paciente".

---

## 6. Negocio: qué validar mientras se construye

### 6.1 Reunión con el fisio colaborador (S1, 1 hora, una sola sesión)

Juntar en una reunión las preguntas que hoy están dispersas en los docs:
1. **Ejercicios** (doc 05 §0): cuáles de los 6, con qué carga, qué variante escapular, series y repeticiones típicas.
2. **Plantillas** (`app.md` §8): 1–2 protocolos de hombro con su progresión por semana.
3. **Duración del programa en casa**: define pacientes por nodo al año, la métrica clave del hardware.
4. **Precio**: *"¿cuánto pagarías al mes por saber qué pacientes sí hacen sus ejercicios en casa?"* Preguntarlo con las dos opciones de `app.md` §6.4 enfrente.
5. **Prueba de los wireframes**: 15 minutos con la lista de pacientes y el flujo de alta. Pedirle que lo use en voz alta, sin explicarle nada.

Repetir 4 y 5 con 1–2 fisios más antes de S5. Si ninguno pagaría el add-on, el pitch cambia y es mejor saberlo en octubre que en Demo Day.

### 6.2 Métricas que el producto debe poder medir desde el primer día

| Métrica | Para qué | De dónde sale |
|---|---|---|
| Activación: % de pacientes con 1.ª sesión ≤ 48 h después de la invitación | Mide si el onboarding funciona | `InviteCode.usedAt` + primera `Session` |
| Apego semanal, **separado** verificado / reportado | El indicador del producto y del pitch | Cálculo de doc 04 §5.3 |
| Pacientes por nodo al año (proyectado) | Economía del hardware (`app.md` §6.3) | `DeviceAssignment` |
| Clínicas activas y retención mensual | Métrica clave del Lean Canvas | `Session` por clínica |

En Demo Day solo se muestran con datos demo, pero que el modelo de datos ya las soporte es lo que vuelve creíble el piloto.

### 6.3 Guion de la demo (3 min de producto)

1. **Problema** (20 s): "Solo 1 de cada 3 pacientes cumple su programa en casa (el 35.3 % del Lean Canvas), y el fisio no sabe quiénes."
2. **Dashboard** (40 s): María (verificado, 38 %, se salta la rotación externa) junto a Juan (reportado). "Con Avena, todos son Juan."
3. **En vivo** (60 s): sesión corta con el reloj, el contador sube; se toma agua y el contador **no** sube.
4. **Cierre del ciclo** (30 s): la sesión aparece en el dashboard como "verificada".
5. **Modelo** (30 s): "El software escala como Avena; el reloj es lo que nadie más tiene."

Pantalla espejo del celular con **scrcpy** (gratis, por USB). No se construye una pantalla espejo propia.

**Plan B:** `SimulatedDevice` activable en 2 toques + video grabado de la demo completa.

---

## 7. Calidad y regulatorio (versión ligera)

Sin frenar el desarrollo, dejar desde ahora lo que después será caro reconstruir:
- **Requisitos con ID** (`REQ-FW-012`, `REQ-APP-004`…) en los docs 01–05, citados en los nombres de las pruebas. Es la trazabilidad mínima para IEC 62304 y la ficha regulatoria.
- **Lista SOUP**: un `SOUP.md` con las librerías de terceros del firmware y de la app (TFLite Micro, ArduinoBLE, flutter_blue_plus…) y su versión.
- **Pruebas que sí o sí existen:** paridad del preprocesamiento (doc 02 §9), contador de repeticiones con señales grabadas, cálculo de apego en el backend, cola offline de la app (idempotencia).
- **Bitácora de auditoría** activa desde el primer endpoint que modifica una prescripción.
- **Etiquetado** en la web: "Datos de ejecución registrados por el dispositivo. No constituye evaluación clínica."

---

## 8. Riesgos principales

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| 1 | Los voluntarios no se agendan a tiempo | Alta | Alto | Agendar en S1; captura de 2 sujetos por sesión; empezar con 10 y completar después |
| 2 | La CNN no llega a F1 ≥ 0.90 | Media | Alto | Edge Impulse como atajo con fecha fija (S4); quitar el ejercicio más confundido (escapular o la rotación interna) |
| 3 | El MTU de BLE limita el modo captura | Media | Medio | Medirlo en S1; lotes chicos o USB serial |
| 4 | El dataset se graba con una orientación distinta a la carcasa final | Media | Alto | Soporte provisional con el tope R1 antes del primer sujeto |
| 5 | El Bluetooth falla en el escenario | Media | Alto | Simulador + video de respaldo + teléfono emparejado de antemano, sin otros dispositivos BLE cerca |
| 6 | Se dispersa el alcance hacia lo que tiene Avena (agenda, chat, cobros) | Alta | Medio | Lista "después" de `app.md` §4 como regla; todo pedido nuevo se compara contra el guion de la demo |
| 7 | Autonomía de batería insuficiente con el core mbed | Media | Bajo para la demo | Medir en S7; documentar la frecuencia de carga |
| 8 | Nadie quiere pagar el add-on de hardware | Media | Alto para el negocio | Entrevistas de precio antes de S5 (sección 6.1) |

---

## 9. Primera semana: checklist

- [ ] `git init`, estructura de carpetas de la sección 2.1 y primer commit con los docs.
- [ ] Corregir en los docs 01–04 los hallazgos 1–3 y 8 de la sección 1.2.
- [ ] Escribir `contracts/ble.yaml` v1 (UUIDs generados una vez, comandos, struct de `EVENTS`, catálogo de IDs).
- [ ] Firmware: pasos 1–3 de doc 02 en PlatformIO; medir el MTU real.
- [ ] Imprimir un soporte provisional con orientación única para la XIAO.
- [ ] Agendar la reunión con el fisio (sección 6.1) y a los primeros 6–8 voluntarios.
- [ ] Wireframes de baja fidelidad: sesión en curso, resumen, lista de pacientes, alta de paciente.
- [ ] API: proyecto NestJS con Prisma, el esquema de la sección 4.5 y un deploy vacío con HTTPS.

## 10. Decisiones que necesito de ti

1. **Fecha de Demo Day** y cuántas personas programan (cambia el calendario de las fases 3–5).
2. **¿Hay código de SmartKnee reutilizable?** (app Flutter, backend NestJS, UI kit). Si sí, conviene revisarlo antes de crear `api/` y `web/` desde cero.
3. **¿Aceptas sacar el modo investigador de la app** y hacerlo en Python (sección 4.2)?
4. **¿Aceptas que el firmware solo cuente** y el backend decida si la sesión está completa (hallazgo #2)?
