# SmartShoulder — 04. Plataforma del fisioterapeuta (+ backend compartido)

**Versión:** 0.1
**Relacionado:** `01-specs-app-paciente.md`, `05-specs-ejercicios-protocolo.md`

---

## 1. Decisión: ¿app de escritorio, o la misma app con otro rol?

**Recomendación: ninguna de las dos. Un dashboard web (Next.js), como ya está en la arquitectura.**

| Opción | A favor | En contra |
|---|---|---|
| App de escritorio nativa (Electron, Flutter Desktop) | Se siente "instalada" | Hay que instalarla en cada PC de clínica, actualizarla y darle soporte en Windows y Mac. No aporta nada que la web no dé. |
| Misma app Flutter con rol "fisio" | Un solo código | El fisio trabaja en una PC con pantalla grande revisando a muchos pacientes; una UI móvil le queda chica. Mezclar roles complica permisos y pruebas. |
| **Dashboard web (Next.js)** | Se abre en cualquier navegador de la clínica sin instalar; pantalla grande para tablas y gráficas; **es el componente que ya validaron los fisioterapeutas en SmartKnee**; reutiliza diseño y código | Requiere internet (aceptable en una clínica) |

En la práctica el dashboard web **se usa como app de escritorio**: el fisio lo abre en la PC del consultorio. Si después piden acceso desde el celular, el dashboard se hace responsive o se agrega una vista ligera; no es prioridad para Demo Day.

## 2. Usuarios y roles

| Rol | Permisos |
|---|---|
| **Fisioterapeuta** | Ve y gestiona solo a sus pacientes: prescribe y revisa adherencia |
| **Admin de clínica** | Gestiona fisioterapeutas, dispositivos de la clínica y pacientes de la clínica |
| **Paciente** | No entra al dashboard; usa la app móvil |

## 3. Funcionalidades

### 3.1 Lista de pacientes (pantalla de entrada)
- Tabla: nombre, diagnóstico/procedimiento (texto libre que captura el fisio), semana de tratamiento, **% de adherencia de los últimos 7 días**, última sesión, alerta.
- **Alertas** (lo de más valor clínico): sin sesión en ≥ 3 días, adherencia < 50 % en la semana, sesiones abortadas repetidas.
- Filtros y orden por adherencia (los de peor apego arriba).

### 3.2 Detalle de paciente
- Calendario de adherencia (completa / incompleta / sin sesión).
- Gráfica de repeticiones hechas contra prescritas por semana.
- Desglose por ejercicio: qué ejercicio se salta más.
- Autorreportes de dolor y esfuerzo en el tiempo (dato del paciente, mostrado como tal).
- Lista de sesiones con su detalle.

### 3.3 Prescripción
- Seleccionar ejercicios del **catálogo** (solo los que el modelo sabe reconocer; doc 05).
- Por ejercicio: series, repeticiones, descanso.
- Frecuencia semanal, fecha de inicio y fin.
- Notas para el paciente.
- Historial de cambios de prescripción (quién cambió qué y cuándo).

### 3.4 Gestión de dispositivos
- Registrar dispositivos por ID BLE.
- Asignar un dispositivo a un paciente para uso en casa, o marcarlo como **dispositivo compartido de clínica** (para instruir al paciente en consulta). Esto ya se había contemplado como escenario de uso.
- Ver batería y versión de firmware/modelo reportadas en la última sincronización.

### 3.5 Reportes
- Exportar el reporte de adherencia de un paciente a PDF (útil para la nota clínica) y a CSV.

## 4. Lo que el dashboard NO muestra (postura regulatoria)

- No muestra "calidad del movimiento", "riesgo de reingreso" ni ninguna inferencia clínica.
- No recomienda cambios de prescripción.
- Etiquetado claro: "Datos de ejecución registrados por el dispositivo". Mantiene el claim acotado a **medición objetiva de apego**, que es la intención de uso declarada.

## 5. Backend compartido (NestJS)

Un solo backend para la app del paciente y el dashboard.

### 5.1 Entidades
```
Clinic, User (role: physio | clinic_admin | patient), Patient (affectedArm, physioId)
Device (bleId, clinicId, assignedPatientId?, shared:boolean, fwVersion, modelVersion)
ExerciseCatalog (id = exercise_id del firmware, name, instructions, videoUrl, enabled)
Prescription, PrescriptionItem
Session, SessionExerciseResult, SessionEvent
AuditLog
```

### 5.2 Endpoints principales (REST)
```
POST   /auth/login
GET    /patients                      (fisio: sus pacientes)
GET    /patients/:id/adherence?from&to
POST   /patients/:id/prescriptions
GET    /me/prescription               (app paciente)
POST   /sessions                      (app sube sesión completa con eventos)
GET    /sessions/:id
POST   /devices  ·  PATCH /devices/:id/assign
POST   /datasets/upload               (CSV del modo investigador)
```

### 5.3 Cálculo de adherencia (definición explícita, para que sea auditable)
- **Adherencia semanal** = sesiones completas en la semana ÷ sesiones prescritas en la semana.
- **Cumplimiento de volumen** = Σ repeticiones hechas ÷ Σ repeticiones prescritas.
- Sesión **completa** = todos los ejercicios con ≥ 90 % de las repeticiones prescritas (umbral configurable y documentado).

### 5.4 Requisitos de seguridad y privacidad
- Datos de salud = **datos personales sensibles** (LFPDPPP): consentimiento expreso, aviso de privacidad, acceso por rol, HTTPS, contraseñas con hash.
- Bitácora de auditoría para cambios de prescripción y accesos a datos de pacientes.
- Base de datos: PostgreSQL, como en SmartKnee.

## 6. Stack

- **Frontend:** Next.js + TypeScript, librería de gráficas (Recharts o similar), UI kit reutilizado de SmartKnee.
- **Backend:** NestJS + PostgreSQL (Prisma o TypeORM).
- **Despliegue para la demo:** un solo servidor (Railway, Render o una VPS) con dominio y HTTPS.

## 7. Alcance para Demo Day

| Sí | Después |
|---|---|
| Lista de pacientes con alertas, detalle con calendario y gráficas, prescripción, export CSV | PDF con formato clínico, multi-clínica completo, integración con expediente clínico, mensajería fisio–paciente |

Para la demo conviene cargar **2–3 pacientes ficticios con semanas de datos simulados** (claramente marcados como demo), además de la sesión real en vivo, para que se vea el valor longitudinal del dashboard.
