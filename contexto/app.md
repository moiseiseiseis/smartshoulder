# SmartShoulder — Benchmark de Avena y plan de la app de adherencia

**Origen:** recomendación del mentor (oct 2026): tomar el esquema de [Avena](https://avena.io/) como referencia casi literal para la app de adherencia y el modelo de negocio. Exploración hecha el 6 oct 2026 a partir del sitio público, Google Play y Trustpilot. Este documento alimenta el Lean Canvas y el entregable "Modelo de negocio / Business Model Plan".

**Actualización 6 oct:** se agregó la sección 6 (cómo entra el wearable al modelo), en respuesta al comentario del mentor de que el hardware a veces frena la escalabilidad.

---

## 1. Qué es Avena, en una línea

SaaS mexicano para **profesionales de la nutrición** (también doctores, entrenadores y clínicas): el profesional arma planes y rutinas en un panel web, y el paciente los sigue en una app gratuita con la marca del profesional. Dice tener más de 200 mil usuarios, 4.9★ en Google Play (500K+ descargas) y clientes corporativos (Farmacias Guadalajara, Novo Nordisk, Sport City, Clivi).

## 2. Anatomía del producto

### 2.1 Panel del profesional (web)
| Módulo | Qué hace |
|---|---|
| Planes de alimentación | 30K recetas, 500+ plantillas por padecimiento, exporta a PDF/Word |
| **Rutinas de ejercicio** | Catálogo con video (o videos propios), series/reps/peso, **plantillas reutilizables** ("arma una vez, reutiliza con quien quieras") |
| Expediente clínico | Historia clínica, antropometría con gráficas, importa PDFs de laboratorio/InBody, notas, adjuntos |
| Agenda | Citas, confirmación por WhatsApp/email/app, recordatorio a 24 h |
| IA | Copiloto de consulta, transcripción de consultas, generación de recetas/rutinas, análisis de fotos de platillos |
| Retos / programas grupales | Varios pacientes en un mismo programa, cobro con Stripe (único o suscripción), app con la marca del profesional |
| Página web profesional | Perfil con SEO + directorio de especialistas, agenda citas directo |
| Reportes (plan clínica) | Consultas y planes por colaborador, **pacientes activos, tasa de retorno**, comparativa vs. periodo anterior |

### 2.2 App del paciente (gratis para el paciente)
Ve su plan y rutinas con video, lista de compras, recordatorios de comida/hidratación, chat con su especialista, **registro de cumplimiento diario** y progreso. En la parte de rutinas, el paciente **anota a mano** las repeticiones y el peso que hizo, y eso llega al panel como "adherencia".

### 2.3 Modelo de negocio
| Plan | Precio regular | Límite |
|---|---|---|
| Básico | $329 MXN/mes | 1–20 pacientes activos/mes |
| Estándar (más popular) | $549 MXN/mes | 1–40, + IA |
| Premium | $999 MXN/mes | 1–80, + IA avanzada |
| Doctores | $499 / $899 MXN/mes | 40 / 80 pacientes |
| Clínica / Empresa | Cotización (Typeform) | Por miembros + pacientes; capacitación, ejecutivo de cuenta, reportes |
| Estudiantes | **Gratis 6 meses** | 8 pacientes/mes; canal de adquisición |
| Docentes / universidades | Por solicitud | Gestión de grupos |

Además: primer mes casi gratis ($15–45 MXN), sin plazo forzoso, varias monedas. El paciente nunca paga a Avena; paga al profesional (y Avena le da la herramienta de cobro).

### 2.4 Lo que dicen los usuarios
- A favor: ahorro de tiempo, facilidad de uso, "los pacientes están encantados de tener su propia app", mejor apego (Avena dice que 94 % de especialistas lo reporta; es una encuesta propia, no un estudio).
- En contra: formularios iniciales largos, curva de aprendizaje para el equipo nuevo, en la app del paciente cuesta intercambiar comidas y ver macros.

## 3. La lectura estratégica (lo que hay que decirle al mentor)

1. **El esquema sí se puede copiar casi tal cual**: el panel para el profesional, la app gratis para el paciente con la marca de la clínica, las plantillas y el modelo SaaS por pacientes activos. Es justo la columna de software que ya validaron los fisios en SmartKnee.
2. **El hueco de Avena es exactamente tu producto.** En Avena la adherencia es **autorreportada**: el paciente escribe que hizo 12 repeticiones. SmartShoulder la **verifica con sensor**. Pitch en una línea: *"Avena para fisioterapeutas, pero el apego no lo dice el paciente: lo mide el reloj."*
3. **Avena es puro software; tú tienes hardware.** Eso cambia costos y precios (secciones 5 y 6) y es lo que te vuelve dispositivo médico.
4. **Avena no es competidor directo** (nutrición, sin sensor, sin enfoque en fisio). Es el referente de modelo de negocio y de UX, y prueba que los profesionales de salud mexicanos sí pagan una suscripción mensual por este tipo de herramienta.

## 4. Mapeo de módulos: qué copiar, cuándo y qué no

| Módulo de Avena | En SmartShoulder | Cuándo |
|---|---|---|
| Rutinas con catálogo de video + series/reps | Catálogo de ejercicios de hombro (doc 05) + prescripción (doc 04) | **Demo Day** |
| Plantillas reutilizables | Protocolos tipo, p. ej. "post-quirúrgico manguito rotador, semanas 1–6", definidos con el fisio colaborador | **Demo Day** (1–2 plantillas) |
| App del paciente gratis con recordatorios | App Flutter (doc 01) + contador en vivo del sensor | **Demo Day** |
| Registro de cumplimiento | **Automático por sensor** (el diferenciador) + autorreporte de dolor/esfuerzo; modo manual sin reloj (sección 6) | **Demo Day** |
| Invitación del profesional al paciente | Código de invitación generado en el dashboard | **Demo Day** |
| Reportes de clínica (pacientes activos, retorno) | Lista de pacientes con alertas de bajo apego + KPIs de clínica | **Demo Day** (versión simple) |
| Marca de la clínica en app y PDFs | Logo y nombre de la clínica en la app y en el reporte de adherencia | Piloto |
| Agenda + confirmación por WhatsApp | Agenda de sesiones presenciales | Después |
| Chat profesional–paciente | Mensajería simple | Después |
| Cobro a pacientes (Stripe) | La clínica cobra al paciente el programa en casa | Después |
| Página web / directorio | Directorio de fisios que usan SmartShoulder | Después |
| Plan gratis para estudiantes / docentes | Licencia gratis para escuelas de fisioterapia (CUTLAJO y similares) | Después; canal de adquisición barato |
| Expediente clínico completo | **No.** Que el fisio use el suyo; integración después | No |
| IA copiloto que recomienda | **No.** Recomendar cambios de tratamiento rompe el claim y empuja la clase de riesgo | No |

**Regla regulatoria:** todo lo que es gestión (agenda, cobros, web, chat) va como **módulos de software separados** del módulo regulado (reconocimiento, conteo y reporte de apego). Es el mismo principio que usaste en el proyecto anterior para separar Módulo 1 y Módulo 2: no dejar que funciones administrativas amplíen el alcance del dispositivo médico.

## 5. Modelo de negocio propuesto (hipótesis para el Lean Canvas)

Estructura copiada de Avena (SaaS por pacientes activos) + componente de hardware. **Todos los números son supuestos a validar con 2–3 fisios.** La sección 6 refina esta tabla separando software y sensor.

| Plan | Para quién | Incluye | Precio hipótesis |
|---|---|---|---|
| Fisio independiente | Fisio con consultorio propio | Dashboard, app de pacientes, hasta ~10 pacientes activos con sensor, **kit de 3–5 nodos en comodato** | $600–900 MXN/mes |
| Clínica | Clínica con varios fisios | Multiusuario, reportes de clínica, marca propia, más nodos, capacitación | Cotización (referencia: $1,500–3,000 MXN/mes) |
| Académico | Escuelas de fisioterapia | Gratis o simbólico, pocos nodos | $0 (adquisición) |

- **El paciente no paga a SmartShoulder** (igual que en Avena). La clínica puede cobrarle el "programa en casa con seguimiento" o un depósito por el nodo.
- **Nodos en comodato** dentro de la suscripción: el nodo se presta al paciente durante su rehab y regresa a la clínica (rota entre pacientes). Esto liga el ingreso recurrente al uso y baja la barrera de entrada. Implica limpieza entre pacientes (ya está en los riesgos de la ficha regulatoria).
- Alternativa a probar: kit de nodos en venta + suscripción de software más barata.
- **Costo unitario del nodo**: recalcular con la XIAO nRF52840 Sense + LiPo + carcasa + correa (pendiente; la lista de compras actual sigue con ESP32).

## 6. El wearable dentro del modelo (respuesta a "el hardware frena la escalabilidad")

### 6.1 El mentor tiene razón en el diagnóstico

Avena escala porque es puro software: costo marginal casi cero por cliente nuevo. Un wearable agrega fricciones que el software no tiene:

| Fricción | Cómo se mitiga en SmartShoulder |
|---|---|
| Capital inicial (hay que fabricar nodos antes de cobrar) | Pocos nodos por clínica (3–5) que rotan entre pacientes; nodo barato y simple (XIAO, carcasa impresa, correa comercial, sin pantalla) |
| Logística e inventario | El nodo **no se envía al paciente**: la clínica lo entrega en consulta y lo recoge al alta. SmartShoulder solo surte a clínicas |
| Pérdida o daño | Depósito reembolsable que cobra la clínica al paciente; reposición con costo de nodo bajo |
| Carga de batería | Sesiones de 20–30 min al día, varios días por carga; la app avisa batería baja |
| Limpieza entre pacientes | Correa individual por paciente (la parte barata) + carcasa lisa desinfectable; ya está como riesgo en la ficha regulatoria |
| Soporte técnico | Emparejamiento guiado desde la app; actualizaciones de firmware por BLE más adelante |
| Trámites (IFT, COFEPRIS) | Costo fijo que se paga una vez y se amortiza con cada clínica |

### 6.2 Pero no conviene quitarlo

- **Sin el reloj, SmartShoulder es un clon de Avena para fisios**: Avena ya tiene módulo de rutinas, cualquiera lo copia en meses. El sensor es lo que no se copia fácil (hardware + dataset propio + modelo + validación).
- **Sin el reloj no hay dispositivo médico**, y el programa es de dispositivos médicos: se pierde la alineación con la convocatoria y con la ficha regulatoria ya entregada.
- La idea no es "hardware o software", sino **que el software escale como Avena y el hardware sea la capa que defiende**.

### 6.3 Tres decisiones de diseño para que el wearable no frene

1. **Software primero, sensor como capa (dos niveles de apego).**
   - **Apego reportado**: cualquier paciente usa la app sin reloj y marca a mano su sesión, como en Avena. Escala a todos los pacientes de la clínica.
   - **Apego verificado**: el paciente con reloj genera datos medidos. Se reserva para donde más valor tiene: fase en casa del post-quirúrgico, pacientes con alerta de bajo apego, primeras semanas del programa.
   - El dashboard muestra ambos **etiquetados distinto** ("reportado por el paciente" vs. "verificado por el dispositivo"), nunca mezclados en el mismo indicador.
   - Pregunta para la preconsulta COFEPRIS: si el modo sin sensor queda fuera del alcance regulado (es la misma lógica de separar módulos de la sección 4).
2. **El reloj es flota de la clínica, no del paciente.** La métrica clave del hardware es **pacientes atendidos por nodo al año**. Supuesto a validar con el fisio: si el programa en casa dura ~6–8 semanas, un nodo atiende ~6 pacientes al año, y 3–5 nodos cubren un consultorio que inicia 2–3 pacientes de hombro al mes.
3. **Un mismo nodo, varios protocolos (roadmap).** El nodo de muñeca puede reconocer ejercicios de codo, muñeca o escápula con otros modelos; más protocolos = más pacientes por nodo sin fabricar más hardware. Evitar rodilla para no pisar SmartKnee.

### 6.4 Modelo de precios con el wearable separado

| Plan | Qué incluye | Precio hipótesis |
|---|---|---|
| **Software** (estilo Avena) | Dashboard, app, plantillas, apego reportado, pacientes ilimitados o por tramos | $300–500 MXN/mes |
| **+ Apego verificado** (add-on) | Kit de 3–5 relojes en comodato, apego verificado, reporte exportable, reposición por desgaste | +$400–700 MXN/mes |
| Clínica | Multiusuario + flota mayor de relojes + capacitación | Cotización |
| Académico | Software gratis + 1–2 relojes para enseñanza | $0 |

Ventaja de partirlo así: la clínica entra barato por el software y sube al add-on cuando ve el valor; el ingreso de hardware queda ligado al uso real.

### 6.5 Escalabilidad a largo plazo (no para Demo Day)

Usar el **smartwatch que ya tiene el paciente** (Wear OS / Apple Watch: el paper de referencia corrió su modelo en un Apple Watch) eliminaría la logística de hardware. Costo: revalidar el modelo por cada marca de reloj, menos control sobre muestreo y colocación, y un expediente regulatorio más complejo (software sobre hardware de terceros). Se menciona en el pitch como ruta de escalamiento, no como producto actual.

### 6.6 Cómo decirlo en el pitch

*"El software escala como Avena; el reloj es lo que nadie más tiene. Cada clínica arranca con software y unos cuantos relojes que rotan entre pacientes; no vendemos un aparato por paciente."*

## 7. Plan de la app de adherencia (alcance Demo Day)

Tomando la estructura de Avena y las specs 01, 04 y 05:

1. **Dashboard del fisio (Next.js)**
   - Alta de paciente → genera código de invitación.
   - Prescripción desde plantilla (protocolo tipo) y ajuste de series/reps.
   - Asignar o no un reloj de la flota al paciente (define si su apego es verificado o reportado).
   - Lista de pacientes ordenada por peor apego, con alertas.
   - Detalle del paciente: calendario de apego, reps hechas vs. prescritas, ejercicio que más se salta, dolor reportado.
   - Panel de clínica: pacientes activos, % de apego promedio, sesiones verificadas en la semana, relojes en uso / disponibles.
2. **App del paciente (Flutter)**
   - Entra con el código de la clínica → (si tiene reloj) lo empareja → ve su sesión de hoy con video de cada ejercicio.
   - Con reloj: contador en vivo del sensor. Sin reloj: marca series a mano.
   - Resumen de sesión; racha; recordatorios.
3. **Backend (NestJS + PostgreSQL)**: el mismo de la spec 04, con entidades `Clinic`, `ProtocolTemplate` (nuevo), `Prescription`, `Session` (con campo `source: verified | reported`), `Device` (flota de la clínica, asignación y devolución).
4. **Datos demo**: 2–3 pacientes ficticios con semanas de historial (marcados como demo), al menos uno sin reloj para mostrar el contraste reportado vs. verificado, + una sesión real en vivo.

Cambios a las specs actuales: agregar `ProtocolTemplate`, panel de KPIs de clínica y gestión de flota a la spec 04; agregar video por ejercicio, onboarding por código de invitación y modo sin reloj a la spec 01; agregar `source` a `Session`.

## 8. Siguientes pasos

1. Validar precio y modelo (software + add-on, comodato vs. venta) con el fisio colaborador y 1–2 fisios más. Preguntas clave: *¿cuánto pagarías al mes por saber qué pacientes sí hacen sus ejercicios en casa?* y *¿cuánto dura el programa en casa de un paciente de hombro típico?* (define pacientes por nodo).
2. Definir con el fisio 1–2 plantillas de protocolo de hombro.
3. Recalcular costo del nodo con la XIAO.
4. Agregar a la preconsulta COFEPRIS la pregunta del modo sin sensor.
5. Llenar el Lean Canvas con las secciones 3, 5 y 6 de este documento.

## Fuentes

- [Avena — inicio, planes y precios](https://avena.io/)
- [Avena para clínicas](https://avena.io/clinicas/)
- [Avena — rutinas](https://avena.io/rutinas/)
- [Avena — expediente clínico](https://avena.io/expedientes-clinicos/)
- [Avena — retos](https://avena.io/retos/)
- [Avena para doctores](https://avena.io/para-doctores/)
- [Avena Health en Google Play](https://play.google.com/store/apps/details?id=com.avena.avenafit&hl=en_US)
- [Avena en Trustpilot](https://es.trustpilot.com/review/avena.io)