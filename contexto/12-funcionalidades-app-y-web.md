# Rumbo Rehab — 12. Qué hace la app del paciente y el dashboard del fisioterapeuta

**Versión:** 1.0 (13 oct 2026), estado real del código en `app/`, `web/` y `api/`.
**Probado:** de punta a punta con hardware real (XIAO `RR-54F5` → app en Galaxy A36 → API → dashboard) el 13 oct 2026.
**Relacionado:** `01` (app), `04` (plataforma del fisio), `09` (plan de mejora), `contracts/ble.md`

---

## 1. En una frase

El fisioterapeuta prescribe ejercicios de hombro en el **dashboard web**; el paciente los hace en casa guiado por la **app**, con un **reloj** que cuenta sus repeticiones; el fisio ve en el dashboard quién sí hizo sus ejercicios, **distinguiendo lo verificado por el reloj de lo reportado a mano**.

## 2. Quién usa qué

| Usuario | Herramienta | Cómo entra |
|---|---|---|
| **Paciente** | App Android "Rumbo" | Con el código de 6 letras o el QR que le da su fisio (sin contraseña) |
| **Fisioterapeuta** | Dashboard web | Correo y contraseña. Ve y gestiona solo a sus pacientes |
| **Administración de la clínica** | Dashboard web | Correo y contraseña. Ve a todos los pacientes de la clínica |

Tono: la app habla de **"usted"**; el dashboard, de **"tú"** (identidad de marca §13).

---

## 3. App del paciente (Flutter, Android)

### 3.1 Entrada (primera vez)

| Pantalla | Qué hace |
|---|---|
| **Splash** | Fondo Crema con el logotipo de Rumbo |
| **Bienvenida** | 3 mensajes cortos que se deslizan: *Bienvenido a Rumbo* → *Su fisioterapeuta le marca el rumbo* → *El reloj cuenta por usted*. Los botones para entrar están siempre visibles (no hace falta deslizar) |
| **Escanear el código** | Abre la cámara y lee el QR que muestra el dashboard (`rumbo://invite?code=…&device=RR-…`) |
| **Escribir el código** | Hoja con un campo grande para las 6 letras o números |
| **Su privacidad** | Aviso en 4 puntos (qué se guarda, quién lo ve, qué no hace la app, sus derechos) y una casilla de consentimiento expreso. Requisito de la LFPDPPP (datos de salud = datos sensibles). *El texto legal final está pendiente de revisión* |
| **Su reloj** | Solo si la clínica le prestó un reloj. Muestra cómo ponérselo (ilustración; se reemplaza por el video de colocación cuando exista), 3 pasos de colocación, botón **Conectar** (pide permiso de "Dispositivos cercanos") y **Hacer parpadear su luz** (el LED azul de la XIAO parpadea para confirmar cuál es su reloj). Se puede dejar para después |

### 3.2 "Su rumbo" (inicio)

- **Saludo** según la hora ("Buenos días, Daniel") con el nombre de su fisio y su clínica.
- **Meta semanal:** anillo con "x de 5" (días con sesión completa contra la frecuencia que prescribió el fisio) y un mensaje: "Le faltan 3 sesiones para su meta de la semana" o "Meta de la semana cumplida".
- **Sendero de la semana:** 7 días (L a D) unidos por un sendero punteado. Cada día muestra: verificado por el reloj (verde con ✓), marcado a mano (ámbar con lápiz), incompleto (punto gris), pendiente (blanco) y **hoy** (Girasol con halo).
- **Semanas cumplidas:** "2 semanas cumplidas".
- **Si lleva días sin sesión:** "No vemos sesiones desde el martes. Cuando pueda, retomamos." Nunca culpa al paciente.
- **Su sesión de hoy:** cuántos ejercicios y minutos aproximados ("Hoy le tocan 2 ejercicios, un par de minutos. ¿Empezamos?"), la lista con miniatura, series × repeticiones y la nota del fisio. Si ya la completó: "Hoy ya completó su sesión".
- **Estado del reloj:** conectado con batería, buscando, desconectado (con botón **Conectar**) o **batería baja** ("Póngalo a cargar antes de su sesión"). Si no tiene reloj: "Sin reloj: marcará sus series a mano".
- **Botón grande:** **Comenzar sesión** (o "Hacer otra sesión").
- **Sesiones sin enviar:** aviso si hay sesiones guardadas en el teléfono esperando internet.
- Al abrir, sube sola las sesiones pendientes y se reconecta al reloj. Se actualiza deslizando hacia abajo.

### 3.3 La sesión (manos libres)

Pensada para que el teléfono esté en una mesa a 1–2 m y el paciente no tenga que tocarlo.

| Momento | Qué pasa |
|---|---|
| **Preparación** | "Coloque el teléfono donde pueda verlo", cuenta regresiva 3-2-1 con voz. La pantalla no se apaga durante toda la sesión |
| **Encabezado** | "Ejercicio 1 de 2", nombre del ejercicio, "Serie 1 de 3" y barra de series (hechas en Índigo, actual en Girasol) |
| **Video del ejercicio** | Clip en bucle, sin audio. **En espejo si el hombro en rehabilitación es el izquierdo.** Mientras no se graben los clips, muestra una tarjeta con el nombre del ejercicio |
| **Contador (con reloj)** | Número grande dentro de un anillo que se llena. Con cada repetición que cuenta el reloj: el número late, el teléfono vibra y suena un tono suave (o la voz cuenta "uno, dos…", si se eligió en Ajustes). Debajo: "El reloj está contando sus repeticiones" |
| **Sin reloj** | "Haga 12 repeticiones" y un botón grande **Terminé la serie** |
| **Aviso suave** | Si el reloj detecta otro ejercicio por más de 4 s: "¿Está haciendo rotación externa?" (sin tono de error) |
| **Si el reloj se desconecta** | "El reloj se desconectó. Acérquelo al teléfono." con botón **Reconectar**. El reloj sigue contando y al reconectar se recuperan las repeticiones |
| **Fin de serie** | Al llegar a las repeticiones, la serie se cierra sola: sonido, "Serie completa" con palomita animada, y empieza el descanso |
| **Descanso** | "Descanse": un círculo que se expande y contrae (Inhale / Exhale) con la cuenta regresiva al centro, y una tarjeta de lo que sigue. Al terminar, arranca sola la siguiente serie ("Siguiente serie en tres, dos, uno"). Botón **Ya estoy listo** para saltarlo |
| **Voz** | Instrucciones en español: "Rotación externa. Serie uno de tres. Doce repeticiones." · "Muy bien. Descanse 45 segundos." · "Sesión completa. Su fisioterapeuta ya puede verla." |
| **Otros controles** | **Saltar ejercicio** y **Terminé la serie** (con reloj, cierra la serie con lo que contó; no inventa repeticiones). La **X** (o el botón atrás) pregunta "¿Terminar la sesión?"; lo hecho se guarda |

### 3.4 Resumen

- **Sesión completa:** la figura del isotipo "sube los brazos" con una animación y suena un tono de logro. Si no se completó: "Hizo 80 de 132 repeticiones. Cada sesión cuenta."
- Etiqueta **Verificado por el reloj** o **Marcado a mano**.
- Repeticiones hechas contra prescritas por ejercicio.
- **¿Cuánto dolor sintió?** Escala propia 0–10 (dos filas de botones grandes, color de verde a rojo, caritas originales en 0, 5 y 10). No usa la escala Wong-Baker, que tiene derechos de autor.
- **¿Qué tan pesado se sintió?** Fácil / Moderado / Muy pesado.
- **Enviar a mi fisioterapeuta:** primero se guarda en el teléfono y luego se sube. Confirma "Enviado. Su fisioterapeuta ya puede verla." o "Guardado en el teléfono. Se enviará cuando tenga internet."
- Después de enviar: cómo va la meta de la semana ("Lleva 3 de 5 sesiones esta semana").

### 3.5 Mi historial

- Resumen: sesiones esta semana, semanas cumplidas y sesiones recientes.
- Calendario de 5 semanas: completa (verde), incompleta (ámbar), sin sesión (gris); hoy con borde Índigo.
- Lista de sesiones con fecha, repeticiones y si fue verificada o marcada a mano.

### 3.6 Ajustes

| Opción | Por omisión |
|---|---|
| Voz con instrucciones | Activada |
| Sonido en cada repetición | Activado |
| Que la voz cuente las repeticiones (en lugar del sonido) | Desactivada |
| Servidor (lo configura la clínica) | — |
| **Reloj simulado (demostración)** — oculto: aparece al tocar 5 veces el título "Ajustes". Genera repeticiones sin el reloj real; es el **plan B del Demo Day** | Desactivado |
| Cerrar sesión | — |

### 3.7 Funciona sin internet

- Toda la sesión ocurre en el teléfono y con el reloj; no necesita internet.
- Las sesiones terminadas se guardan y se suben cuando hay conexión, con reintentos. Un identificador único por sesión evita que se dupliquen en el servidor.

### 3.8 Accesibilidad

Texto base de 18 (nunca menos de 15), botones de 56 dp o más, contraste AA, estados con ícono + color + texto, etiquetas para TalkBack (el contador anuncia "3 de 12 repeticiones"), respeta "quitar animaciones" del sistema y el tamaño de letra del sistema. *Pendiente:* revisión formal con letra al 130 % y TalkBack en el A36 (doc 09 §7).

### 3.9 Cómo habla con el reloj (Bluetooth LE)

La app no procesa la señal: manda comandos y recibe eventos (contrato en `contracts/ble.md`).
- Al iniciar: modo inferencia, brazo en rehabilitación e inicio de sesión.
- En cada serie le dice al reloj qué ejercicio esperar; en el descanso, ninguno.
- Recibe cada repetición con su número y una secuencia que permite detectar y recuperar eventos perdidos.
- Lee la batería, la versión de firmware y la del modelo, que viajan con cada sesión para la trazabilidad.

---

## 4. Dashboard del fisioterapeuta (web)

### 4.1 Pacientes (pantalla de entrada)

Responde a *"¿a quién tengo que llamar hoy?"*.

- Tabla ordenada: **primero los que tienen alertas**, luego por peor apego.
- Por paciente: nombre, diagnóstico, semana de tratamiento, **apego de los últimos 7 días** con barra, origen (**Verificado** con su reloj `RR-…` o **Reportado**), última sesión y alertas.
- **Alertas:**
  - **Sin sesión** en 3 días o más.
  - **Apego menor a 50 %** en la semana (solo con 3 días o más de tratamiento).
  - **Sesiones abandonadas repetidas** (2 de las últimas 3).
- Filtros (todos, con alerta, con reloj, sin reloj) y búsqueda por nombre.
- Se actualiza sola cada 10 s. En celular se acomoda en tarjetas.

### 4.2 Detalle del paciente

- **Resumen de 7 días** por origen: apego (sesiones completas contra esperadas) y volumen (repeticiones hechas contra esperadas). Verificado y reportado **nunca se suman**.
- **Calendario de apego** desde el inicio del tratamiento: completa, incompleta, abandonada, sin sesión, días reportados marcados con lápiz y días previos al inicio punteados.
- **Repeticiones por semana:** esperadas contra hechas (verificadas y reportadas por separado).
- **Por ejercicio:** cumplimiento y sesiones con menos del 50 %; destaca **"El que más se salta"**.
- **Dolor y esfuerzo** en el tiempo, marcado como **reportado por el paciente**.
- **Lista de sesiones** con duración, estado, origen y repeticiones.
- **Reloj:** código, batería, última vez visto; **Registrar devolución** o **Prestar reloj** (elige uno disponible).
- **App del paciente:** si ya entró, el **QR y el código** de invitación (vence en 14 días) y **Nuevo código**.
- **Prescripción:** ejercicios, frecuencia, notas; **Cambiar** abre el editor; historial de cambios con fecha y autor.
- **Exportar CSV** (una fila por ejercicio por sesión, con origen, reloj, versión del modelo, dolor y esfuerzo).
- **Dar de alta:** archiva al paciente y su reloj regresa a la clínica para limpieza.
- Se actualiza sola cada 5 s: una sesión hecha en la app aparece sin recargar.
- Leyenda fija: *"Datos de ejecución registrados por el dispositivo o reportados por el paciente. No constituyen una evaluación clínica."*

### 4.3 Nuevo paciente (3 pasos)

1. **Paciente:** nombre, hombro en rehabilitación (derecho o izquierdo) y diagnóstico en texto libre.
2. **Prescripción:** partir de una **plantilla** (hoy: *Post-quirúrgico manguito rotador · fase intermedia* y *Tendinopatía del supraespinoso*) y ajustar ejercicios, series, repeticiones, descanso, días por semana y notas. Solo se pueden prescribir los ejercicios que el reloj sabe reconocer.
3. **Reloj:** sin reloj (apego reportado) o prestar uno disponible (apego verificado), con cuántos pacientes ha atendido.

Al terminar muestra el **QR y el código** para que el paciente entre a la app; si se le prestó reloj, el QR también lo identifica.

### 4.4 Relojes (flota de la clínica)

- Cada reloj con estado (**Disponible**, **Prestado**, **En limpieza**, **Dado de baja**), paciente, batería, última sesión, versiones de firmware y modelo, y **pacientes atendidos** (métrica clave del modelo de negocio).
- Acciones: **Registrar devolución** (pasa a limpieza) y **Limpio · disponible**.
- **Registrar reloj nuevo** por su nombre Bluetooth (`RR-XXXX`, impreso en la carcasa).

### 4.5 Clínica

Pacientes activos (con y sin reloj), pacientes que necesitan atención, relojes en uso, y por separado para **verificado** y **reportado**: apego promedio y sesiones de los últimos 7 días.

---

## 5. Reglas que aplican en todo el sistema

| Regla | Detalle |
|---|---|
| **Sesión completa** | Todos los ejercicios con al menos el **90 %** de sus repeticiones. Lo decide el servidor, no la app |
| **Apego** | Sesiones completas ÷ sesiones esperadas (frecuencia semanal prorrateada a los días activos) |
| **Meta semanal (app)** | Días con sesión completa de lunes a domingo contra la frecuencia prescrita. Reemplaza a la "racha", que castigaba los días de descanso indicados por el fisio |
| **Verificado ≠ reportado** | Se calculan, muestran y exportan por separado; siempre con ícono + color + texto |
| **Días** | Se cuentan en hora de la clínica (Ciudad de México) |
| **Trazabilidad** | Cada sesión guarda reloj, versión de firmware y versión del modelo. Los cambios de prescripción, altas y movimientos de relojes quedan en una bitácora de auditoría |
| **Seguridad** | Contraseñas con hash, sesión del fisio de 12 h, sesión del paciente de 90 días, acceso por rol (el paciente no puede ver datos de otros) |

## 6. Lo que el sistema no hace (postura regulatoria)

No diagnostica, no evalúa la calidad del movimiento, no recomienda cambios de tratamiento y no infiere riesgos clínicos. **Mide y registra la ejecución de lo que el fisioterapeuta prescribió.** El dolor y el esfuerzo son datos que reporta el paciente y se muestran como tales.

## 7. Datos y accesos de demostración

| Qué | Valor |
|---|---|
| Dashboard | `fisio@demo.mx` / `demo1234` (fisio) · `admin@demo.mx` / `demo1234` (clínica) |
| App | Código **DEMO23** → paciente **Daniel Ramírez** con el reloj real **RR-54F5** |
| Pacientes demo | María (verificada, se salta la rotación externa, sin sesión hace días) · Carmen (abandona sesiones) · Juan (reportado, apego bajo) · Roberto (reportado "perfecto") · Ana (verificada, constante) · Daniel (demo en vivo) |

Los datos demo se regeneran con `npm run db:seed` (borra la base). Correrlo la mañana del Demo Day.

## 8. Limitaciones actuales

- **El reloj aún no distingue ejercicios:** el firmware 1.1 cuenta cualquier movimiento de ida y vuelta como repetición del ejercicio que espera la app. El clasificador llega con el modelo (firmware v2), después de la captura del dataset.
- **Videos de los ejercicios:** pendientes de grabar (doc 10); mientras tanto se muestra una tarjeta de respaldo.
- **Solo Android.** iOS, recordatorios diarios, mensajes con el fisio y modo oscuro quedan para después del Demo Day.
- **Aviso de privacidad:** borrador, falta revisión legal.
- **Accesibilidad:** falta la revisión formal en el A36 y la prueba con usuarios (doc 09 §7–8).
