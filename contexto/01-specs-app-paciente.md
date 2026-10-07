# SmartShoulder — 01. Especificaciones genéricas de la app del paciente (Flutter)

**Versión:** 0.1 (borrador para prototipo de Demo Day)
**Relacionado:** `02-specs-firmware-xiao.md` (protocolo BLE), `04-specs-plataforma-fisioterapeuta.md` (backend compartido), `05-specs-ejercicios-protocolo.md` (catálogo de ejercicios)

---

## 1. Propósito

App móvil que guía al paciente durante su sesión de ejercicios de hombro en casa, se conecta por Bluetooth al wearable (XIAO nRF52840 Sense), muestra el conteo de repeticiones en tiempo real y envía la sesión al backend para que el fisioterapeuta vea el apego terapéutico.

**Lo que la app NO hace** (alineado con la postura regulatoria del proyecto): no diagnostica, no evalúa la calidad clínica del movimiento, no modifica la prescripción. Solo guía, cuenta y registra la ejecución de lo que el fisioterapeuta prescribió.

## 2. Usuarios y roles dentro de la app

| Rol | Quién | Qué ve |
|---|---|---|
| **Paciente** | Persona en rehab de hombro | Su prescripción, guía de sesión, historial propio |
| **Investigador** (oculto, solo builds internos) | Moisés / equipo | Modo captura de datos para entrenar el modelo (ver sección 6) |

El fisioterapeuta **no** usa esta app; tiene su propia plataforma (ver doc 04).

## 3. Stack técnico

- **Framework:** Flutter (Android primero; iOS si da tiempo).
- **BLE:** `flutter_blue_plus`.
- **Estado:** Riverpod o Bloc (lo que ya se usó en SmartKnee, para reutilizar).
- **Almacenamiento local:** `sqflite` o `hive` para guardar sesiones sin conexión.
- **HTTP:** `dio` contra el backend NestJS.
- **Auth:** JWT emitido por el backend (mismo esquema que SmartKnee).

## 4. Pantallas y flujos

### 4.1 Onboarding y emparejamiento
1. Login (correo + contraseña, o código de invitación que genera el fisio).
2. Aviso de privacidad y consentimiento (LFPDPPP, datos de salud = datos sensibles).
3. Emparejar dispositivo: escaneo BLE filtrado por el UUID de servicio de SmartShoulder → seleccionar → guardar ID del dispositivo.
4. Indicar en qué brazo se coloca el dispositivo (**el brazo que se rehabilita**). El dato se envía al firmware porque afecta la orientación de los ejes (ver doc 03, espejado izquierda/derecha).

### 4.2 Inicio (Home)
- Sesión de hoy: ejercicios prescritos, series × repeticiones.
- Estado del dispositivo: conectado/desconectado, batería (%).
- Racha de días con sesión completa.
- Botón grande: **"Comenzar sesión"**.

### 4.3 Guía de sesión (pantalla principal del producto)
- Ejercicio actual: nombre, video o animación corta, indicaciones clave (de doc 05).
- **Contador de repeticiones en vivo**, alimentado por los eventos BLE del dispositivo.
- Serie actual / total de series.
- Temporizador de descanso entre series.
- Indicador de "ejercicio detectado" (lo que el modelo reconoce) contra "ejercicio esperado". Si no coinciden por más de N segundos, mostrar un aviso suave ("¿Estás haciendo *abducción*?"), sin tono de error.
- Botones: pausar, saltar ejercicio (registrar motivo), terminar sesión.

### 4.4 Resumen de sesión
- Repeticiones hechas contra prescritas, por ejercicio.
- Sesión completa / incompleta.
- Autorreporte opcional: dolor (EVA 0–10) y esfuerzo percibido. Es dato reportado por el paciente, no medido por el sensor; dejarlo así para no ampliar el claim.
- Enviar al backend (o encolar si no hay internet).

### 4.5 Historial
- Calendario de adherencia (días con sesión completa, incompleta o sin sesión).
- Detalle por sesión.

### 4.6 Recordatorios
- Notificación local a la hora que elija el paciente o que sugiera el fisio.

## 5. Comunicación con el dispositivo

La app **no procesa señal**: el dispositivo clasifica y cuenta, y la app solo recibe eventos. El contrato BLE completo está en doc 02, sección 6. En resumen:

| Dirección | Mensaje |
|---|---|
| App → dispositivo | `START_SESSION` (con lista de ejercicios esperados), `STOP_SESSION`, `SET_ARM` (izq/der), `SET_MODE` (inferencia/captura), sincronización de hora |
| Dispositivo → app | `REP_EVENT` (ejercicio, número de rep, confianza, timestamp), `EXERCISE_CHANGED`, `BATTERY`, `RAW_BATCH` (solo en modo captura) |

**Reconexión:** si se pierde BLE a mitad de sesión, el dispositivo sigue contando y guarda los eventos en un búfer; al reconectar, la app pide el volcado (`SYNC_EVENTS`).

## 6. Modo investigador (captura de datos)

Necesario para construir el dataset de entrenamiento (doc 03 y doc 05). Solo en builds internos:
- Seleccionar sujeto (ID anónimo), brazo y ejercicio a grabar.
- Poner el dispositivo en `MODE_CAPTURE` → recibe la señal cruda (6 ejes, 50 Hz).
- Botones "inicio de serie" / "fin de serie" que insertan marcas de etiqueta.
- Opción de marcar cada repetición con un toque (etiqueta fina para entrenar el conteo).
- Exporta CSV: `timestamp_ms, ax, ay, az, gx, gy, gz, label, rep_marker, subject_id, arm`.
- Subir el CSV al backend o compartirlo por archivo.

## 7. Modelo de datos (lado app)

```
Patient { id, name, affectedArm, deviceId }
Prescription { id, patientId, exercises: [ { exerciseId, sets, reps, restSec } ], frequencyPerWeek, startDate, endDate }
Session { id, patientId, prescriptionId, startedAt, endedAt, status: complete|incomplete|aborted, painScore?, effortScore? }
SessionExerciseResult { sessionId, exerciseId, repsDone, repsPrescribed, setsDone }
SessionEvent { sessionId, type, exerciseId, repIndex, confidence, deviceTimestamp }
```

## 8. Requisitos no funcionales

- **Funciona sin internet** durante la sesión; sincroniza después.
- **Latencia** del evento de repetición, del dispositivo a la pantalla: < 500 ms (para que el contador se sienta en vivo).
- **Accesibilidad:** textos grandes y botones grandes. Muchos pacientes de hombro son adultos mayores y operan con una sola mano.
- **Privacidad:** cifrado en tránsito (HTTPS) y datos locales mínimos.

## 9. Alcance para Demo Day contra después

| Demo Day (sí) | Después (no prometer) |
|---|---|
| Android, emparejamiento, guía de sesión, contador en vivo, resumen, historial básico, modo captura | iOS pulido, videos profesionales, gamificación, integración con expediente clínico, multi-idioma |
