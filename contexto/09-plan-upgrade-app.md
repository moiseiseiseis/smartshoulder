# Rumbo Rehab — 09. Plan de mejora de la app del paciente

**Versión:** 0.1 (12 oct 2026)
**Ventana:** 3 días de trabajo mientras llegan las piezas nuevas de la carcasa (la LiPo no entró en la primera impresión).
**Relacionado:** `01-specs-app-paciente.md`, `07-plan-desarrollo-digital.md` §5 (UX), `08-marca-rumbo-rehab.md`, `10-guia-grabacion-videos.md`

---

## Estado (13 oct 2026)

Hecho, con la marca de `brand/identidad-marca-rumbo-rehab.md`:
- [x] Renombre completo (doc 08 §6): app `mx.rumborehab.app` ("Rumbo"), reloj `RR-XXXX`, `firmware/rumbo`, `ml/rumbo_ml`, base `rumbo-db`, QR `rumbo://invite`.
- [x] Sistema visual en Flutter: tokens, Nunito incluida (OFL), íconos Lucide, ícono adaptable de Android, splash.
- [x] Meta semanal (§3.1) en backend (`weekProgress`, con pruebas) y app: anillo, sendero de 7 días, semanas cumplidas.
- [x] Sesión: anillo, pulso por repetición con vibración y sonido propio, barra de series, video en espejo para hombro izquierdo (con tarjeta de respaldo mientras no hay clips), descanso con respiración, "Serie completa", aviso si el reloj se desconecta.
- [x] Resumen: la figura sube los brazos, escala de dolor propia (§3.2), meta de la semana tras enviar.
- [x] Bienvenida, privacidad, emparejamiento con ilustración de colocación, historial, ajustes (voz, sonido, voz que cuenta) y estados vacíos y de error. Textos en "usted".
- [x] Dashboard con la marca (Nunito, colores, logotipo, favicons, íconos de estado).

Pendiente:
- [ ] Integrar los 7 videos cuando se graben (doc 10).
- [ ] Reflashear la XIAO para que se anuncie como `RR-54F5`.
- [ ] Revisión en el A36: letra al 130 %, TalkBack y rendimiento (§7).
- [ ] Prueba con usuarios (§8).

---

## 1. Objetivo

Que la app sea **atractiva, disfrutable, intuitiva, profesional pero familiar**. Hoy es correcta y funciona de punta a punta con el reloj real, pero se siente como un formulario. La meta es que se sienta como un **acompañante de la rehabilitación**.

La pantalla de **sesión en curso** es la estrella: es la que el paciente usa a diario y la que el jurado verá en vivo en el Demo Day.

## 2. Principios

1. **"Rumbo" como hilo conductor.** La rehabilitación es un camino: cada sesión es un paso, la semana es un tramo, el alta es el destino.
2. **Manos libres en la sesión.** El teléfono está en una mesa a 1–2 m y el brazo está ocupado: todo se lee a distancia y se escucha.
3. **Celebrar sin infantilizar.** Refuerzo positivo proporcional al logro; sin tablas de posiciones ni presión.
4. **Nunca regañar ni culpar.** Si se saltó un día, la app anima a volver; no muestra pérdidas.
5. **Para adultos mayores primero.** Letra grande, botones grandes, una acción principal por pantalla, mensajes claros cuando algo falla.
6. **Postura regulatoria intacta** (doc 04 §4): la app guía, cuenta y registra; no evalúa la calidad del movimiento ni recomienda cambios.

## 3. Dos correcciones de fondo

### 3.1 Meta semanal en lugar de racha diaria
**Problema:** hoy la app cuenta días seguidos con sesión. El fisio prescribe, por ejemplo, 5 días por semana, así que el paciente que descansa el día que le toca descansar "pierde la racha". La app castiga lo que el tratamiento indica.
**Cambio:** anillo de **"3 de 5 sesiones esta semana"** y celebración de **semanas cumplidas**. Es mejor experiencia y clínicamente correcto.
**Implica:** un cambio chico en el backend (`GET /me/sessions` devuelve el progreso de la semana y las semanas cumplidas).

### 3.2 Escala de dolor propia
**No usar la escala de caritas Wong-Baker:** tiene derechos de autor y su uso requiere licencia.
**Cambio:** escala numérica 0–10 con gradiente de color y caritas originales en los extremos y el centro. Se conserva el formato actual de dos filas de botones de 56 dp.

## 4. Qué cambia, por área

| Área | Cambios | Por qué |
|---|---|---|
| **Identidad** | Nombre Rumbo Rehab, ícono, splash animado breve, paleta y tipografía nuevas, tono de voz | Primera impresión ante pacientes y jurado |
| **Bienvenida** | 3 pantallas: *tu fisio prescribe → el reloj cuenta → tu fisio ve tu avance*. Ilustración o foto del reloj en la muñeca con la flecha ▲ hacia los dedos | Explica el valor en 20 s. La orientación correcta del reloj importa para el modelo |
| **"Tu rumbo" (inicio)** | Saludo según la hora, semana como camino de 7 pasos, anillo de meta semanal, tarjeta de la sesión de hoy con miniaturas de video, estado del reloj | El paciente ve hacia dónde va, no solo una lista |
| **Sesión en curso** | Anillo de progreso alrededor del contador, animación en cada repetición, sonido suave por repetición, video del ejercicio en bucle, transición clara entre ejercicios | Es la pantalla del día a día y del Demo Day |
| **Descanso** | Círculo que se expande y contrae para guiar la respiración, cuenta regresiva, adelanto del siguiente ejercicio con su video | Convierte la espera en algo tranquilo |
| **Celebraciones** | Pequeña al terminar una serie, mayor al terminar la sesión, especial al cumplir la meta semanal | Refuerzo positivo proporcional |
| **Resumen** | Escala de dolor nueva, mensajes positivos según el resultado, confirmación de envío al fisio | Cierre que motiva a volver mañana |
| **Historial** | Calendario con el mismo lenguaje de colores que el dashboard, semanas cumplidas, detalle por sesión | Coherencia con lo que ve el fisio |
| **Estados vacíos y de error** | Sin internet, sin reloj, reloj con batería baja, reloj no encontrado, primera vez sin sesiones. Siempre con un mensaje humano y una acción clara | Lo que más frustra a un adulto mayor es no saber qué hacer |
| **Accesibilidad** | Revisión completa (§7) | El público principal |

## 5. Animaciones y videos

**Se usan las dos, cada una para lo suyo.**

### Videos: para los ejercicios
- Para un adulto mayor, una persona real haciendo el movimiento es más clara y genera más confianza que una ilustración.
- Una animación profesional de 6 ejercicios no se hace bien en 3 días; un video con el celular, sí.
- Especificación: clips de **5–8 s en bucle**, sin audio, cuadrados (1:1), **menos de 1 MB cada uno**, incluidos en la app (funcionan sin internet).
- Se graban **solo con el brazo derecho**; para pacientes de hombro izquierdo la app los muestra **en espejo**.
- Muestran el reloj Rumbo puesto, así que también enseñan el producto.
- Guía completa de grabación: `10-guia-grabacion-videos.md`.

### Animaciones: para la interfaz
Hechas en Flutter (sin archivos externos ni licencias):
- Contador: escala breve y anillo que avanza con cada repetición.
- Descanso: círculo de respiración.
- Transiciones entre pantallas y entre ejercicios.
- Celebraciones: palomita animada al terminar una serie; animación de cierre al terminar la sesión.
- Duraciones cortas (150–400 ms) y respeto a la opción del sistema de reducir animaciones.

## 6. Sonido

Decisión de Moisés:

| Momento | Por omisión | Opcional en Ajustes |
|---|---|---|
| Instrucciones ("Rotación externa, serie uno de tres, doce repeticiones") | **Voz** | Silenciar |
| Cada repetición | **Sonido suave** | Voz que cuenta ("uno, dos, tres…") |
| Fin de serie y cuenta regresiva del descanso | Voz | — |
| Fin de sesión | Voz + sonido de logro | — |

Los sonidos deben ser propios o con licencia libre para uso comercial, cortos (< 300 ms) y agradables a volumen alto.

## 7. Lista de accesibilidad

- [ ] Letra al **130 %** del sistema (Samsung) sin cortes ni textos encimados en ninguna pantalla.
- [ ] **TalkBack**: todos los botones e íconos con etiqueta en español; orden de lectura lógico.
- [ ] Contraste AA en todos los textos (4.5:1; 3:1 en textos grandes).
- [ ] Objetivos táctiles de **48 dp como mínimo** (56 dp en acciones principales).
- [ ] Nada se comunica solo con color.
- [ ] Opción del sistema "quitar animaciones" respetada.
- [ ] Funciona con una sola mano (acciones principales en la mitad inferior).
- [ ] Rendimiento fluido (60 fps) en el Galaxy A36 durante la sesión con video.

## 8. Prueba con usuarios (día 3)

**Quién:** 1–2 personas de **50 años o más**, idealmente sin experiencia con la app. Si se puede, una con problemas de hombro.
**Duración:** 15 minutos por persona.
**Cómo:** el celular con la app, el reloj y una banda elástica. Moisés observa y anota; no ayuda salvo que la persona se atore más de 1 minuto.

**Instrucción inicial (leer tal cual):**
> "Vamos a probar una app, no a usted. Si algo no se entiende, es culpa de la app. Piense en voz alta mientras la usa: dígame qué espera que pase y qué le confunde."

**Tareas:**

| # | Tarea | Éxito si… |
|---|---|---|
| 1 | "Su fisioterapeuta le dio este código. Entre a la app." | Entra sin ayuda en menos de 1 min |
| 2 | "Conecte su reloj y póngaselo." | Lo conecta y lo coloca con la flecha hacia los dedos |
| 3 | "Haga su sesión de hoy." (sesión corta) | La completa sin tocar el teléfono durante las series |
| 4 | "Dígale a su fisio cuánto le dolió." | Marca el dolor y envía |
| 5 | "¿Cuántas sesiones le faltan esta semana?" | Lo encuentra en el inicio en menos de 20 s |

**Al final, 3 preguntas:**
1. ¿Qué fue lo más confuso?
2. ¿La usaría todos los días? ¿Por qué?
3. ¿Le habló bien la app? (para validar "tú" o "usted", doc 08 §4)

**Qué anotar:** dónde dudó, qué tocó por error, qué leyó en voz alta, cuánto tardó en cada tarea. Lo que falle en 2 de 2 personas se corrige antes de congelar.

## 9. Plan día por día

| Día | Claude | Moisés |
|---|---|---|
| **Día 1** | 3 direcciones de marca; renombre completo (doc 08 §6); sistema visual en la app (colores, tipografía, componentes, tiempos de animación); ícono y splash; meta semanal en backend y app | Elegir la dirección de marca y decidir "tú" o "usted". **Grabar los 7 videos** (doc 10) y que el fisio los valide |
| **Día 2** | Sesión completa: anillo, animaciones, sonidos, videos integrados y en espejo, descanso con respiración, celebraciones, resumen con la escala de dolor nueva | Probar en el A36 lo que vaya quedando y reportar lo que no guste |
| **Día 3** | Bienvenida, "Tu rumbo", historial, estados vacíos y de error, accesibilidad (§7), rendimiento en el A36, correcciones de la prueba, **congelar versión** | **Prueba con usuarios** (§8) en la mañana. Revisar la versión congelada |
| En paralelo | Marca en el dashboard web (~30 min) | — |

## 10. Definición de "terminado"

- [ ] Las tareas 1–5 de la prueba con usuarios se completan sin ayuda.
- [ ] La lista de accesibilidad (§7) está completa.
- [ ] La sesión corre fluida en el A36 con video, animaciones y reloj real.
- [ ] El modo de reloj simulado (plan B del Demo Day) sigue funcionando.
- [ ] La app funciona sin internet durante la sesión y sube después.
- [ ] Pruebas automáticas en verde y `flutter analyze` sin avisos.
- [ ] APK de la versión congelada generado y probado en el A36.

## 11. Fuera de alcance (después del Demo Day)

Recordatorios diarios con notificación, iOS, mensajes del fisio, modo oscuro, más idiomas, ilustraciones o animaciones profesionales de los ejercicios.

## 12. Riesgos

| Riesgo | Mitigación |
|---|---|
| Los videos no se graban a tiempo | La sesión funciona sin video (instrucciones en texto); se integran cuando lleguen |
| Los videos pesan demasiado o se traban en el A36 | Compresión a < 1 MB, resolución de 480–720 px y prueba de rendimiento el día 2 |
| La marca no se decide el día 1 | Se avanza con el sistema visual usando colores provisionales fáciles de cambiar (tokens) |
| Demasiadas animaciones cansan o distraen | Duraciones cortas y opción del sistema para reducirlas; se valida en la prueba con usuarios |
