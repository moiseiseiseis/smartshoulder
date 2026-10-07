# SmartShoulder — 05. Ejercicios: catálogo, ejecución y protocolo de captura de datos

**Versión:** 0.1. **Pendiente de validar con el fisioterapeuta antes de grabar el dataset definitivo.**
**Relacionado:** `03-specs-modelo-tinyml.md`, `01-specs-app-paciente.md`

---

## 0. Advertencia de alcance

Este documento describe los ejercicios **para construir el dataset con voluntarios sanos** y para la demo. No es una prescripción clínica: en pacientes reales, rango de movimiento, carga, series y progresión los define el fisioterapeuta según el caso (postquirúrgico, tendinopatía, etc.). El set de partida es el del paper de referencia; el fisio puede quitar, cambiar o agregar ejercicios. Cada cambio implica regrabar datos de ese ejercicio.

**Preguntas para el fisio antes de grabar:**
1. ¿Cuáles de estos 6 son los que más prescribe en rehab de hombro?
2. ¿Con banda elástica, sin carga o con mancuerna ligera?
3. ¿Qué variante de "estabilización escapular" usa (retracción, remo con banda, otra)?
4. Series y repeticiones típicas, para fijar los valores por defecto de la app.
5. ¿Qué errores de ejecución ve más seguido? (Solo para el roadmap; no se medirán en Demo Day.)

## 1. Colocación del dispositivo (igual para todos los ejercicios)

- En la **muñeca del brazo que se ejercita**, dorsal (como un reloj), 1–2 cm arriba del hueso de la muñeca (apófisis estiloides).
- Siempre con la **misma orientación**: la carcasa tiene una marca (p. ej. "▲ hacia los dedos"; ver doc 06).
- Ajustado sin apretar: que no gire alrededor de la muñeca.

## 2. Catálogo de ejercicios

`exercise_id` coincide con el ID de clase del modelo (doc 03) y el del firmware.

### ID 1 — Flexión anterior de hombro
- **Posición inicial:** de pie, brazo extendido a un costado, palma hacia el cuerpo.
- **Movimiento:** elevar el brazo **hacia el frente** con el codo extendido hasta la altura indicada (en sanos, hasta ~150–180°, o 90° si así se define), y bajar controlado.
- **Ritmo:** ~2 s de subida y ~2 s de bajada.
- **Defecto en app:** 3 × 10.
- **Qué ve el IMU:** gran cambio de inclinación del acelerómetro en el plano sagital; giroscopio dominante en un solo eje.

### ID 2 — Abducción de hombro
- **Posición inicial:** de pie, brazo a un costado, palma hacia el cuerpo o hacia el frente (fijar una sola con el fisio).
- **Movimiento:** elevar el brazo **hacia el lateral** (o en plano escapular, ~30° al frente del lateral, según el fisio) hasta 90° o lo indicado, y bajar.
- **Ritmo:** 2 s / 2 s.
- **Defecto:** 3 × 10.
- **Qué ve el IMU:** parecido a la flexión, pero en otro plano; la diferencia está en **qué eje** del giroscopio domina. Es la confusión a vigilar contra ID 1.

### ID 3 — Rotación externa (con banda elástica)
- **Posición inicial:** de pie o sentado, codo pegado al costado a 90° (opcional: toalla enrollada entre codo y tronco), antebrazo al frente, banda anclada del lado contrario.
- **Movimiento:** girar el antebrazo **hacia afuera** manteniendo el codo pegado; regresar controlado.
- **Ritmo:** 2 s / 2 s.
- **Defecto:** 3 × 12.
- **Qué ve el IMU:** la muñeca describe un arco horizontal; giroscopio alrededor del eje vertical con un signo.

### ID 4 — Rotación interna (con banda elástica)
- **Posición inicial:** igual que ID 3, pero con la banda anclada del **mismo** lado del brazo.
- **Movimiento:** girar el antebrazo **hacia el abdomen** con el codo pegado; regresar.
- **Defecto:** 3 × 12.
- **Qué ve el IMU:** el mismo arco que ID 3 pero con el **signo opuesto** del giroscopio. Por eso el espejado izquierda/derecha (doc 03) tiene que estar bien hecho.

### ID 5 — Extensión de tríceps (jalón con banda)
- **Posición inicial:** de pie, banda anclada arriba (marco de puerta), codos pegados al cuerpo y flexionados a 90°.
- **Movimiento:** extender los codos hacia abajo hasta estirar el brazo; regresar a 90°.
- **Defecto:** 3 × 12.
- **Qué ve el IMU:** arco vertical corto de la muñeca; patrón distinto a la flexión porque el húmero casi no se mueve.

### ID 6 — Estabilización escapular (remo con banda / retracción)
- **Posición inicial:** de pie, banda anclada al frente a la altura del pecho, brazos extendidos al frente.
- **Movimiento:** jalar hacia atrás llevando los codos junto al cuerpo y **juntando las escápulas**; sostener 1–2 s y regresar.
- **Defecto:** 3 × 10.
- **Qué ve el IMU:** desplazamiento antero-posterior de la muñeca con pausa al final.
- **Riesgo:** si el fisio prefiere una retracción escapular **sin** mover los brazos, la muñeca casi no se mueve y el IMU puede no distinguirla. En ese caso, o se usa la variante con remo, o se saca del set inicial.

### ID 0 — NULO (no es ejercicio, pero hay que grabarlo)
Actividades que el modelo debe aprender a **ignorar**:
- reposo de pie y sentado, con el brazo quieto,
- caminar balanceando los brazos,
- usar el celular, tomar un vaso, peinarse, rascarse la cabeza (movimientos de hombro cotidianos parecidos a los ejercicios),
- transiciones: acomodar la banda, sacudir el brazo entre series.

## 3. Protocolo de captura del dataset

### 3.1 Participantes
- **Meta:** 15–20 voluntarios sanos (estudiantes del CU) como primera versión; el paper usó 20.
- Variedad de estatura, complexión y sexo. Que algunos sean zurdos o graben con el brazo no dominante.
- Consentimiento informado por escrito (aunque sean sanos, se registran datos personales), con ID anónimo por sujeto.

### 3.2 Por sujeto (≈ 30–40 min)
1. Colocar el dispositivo según la sección 1. Registrar sujeto, brazo y fecha.
2. Explicación y demostración de cada ejercicio (video o el investigador en vivo).
3. Por cada ejercicio (ID 1–6):
   - 1 serie de práctica (no se graba),
   - **3 series de 10 repeticiones**: una a ritmo normal, una **lenta** y una **rápida** (variabilidad),
   - marcar inicio y fin de cada serie en la app,
   - opcional: un ayudante marca cada repetición con un toque, o se graba video sincronizado para etiquetar después.
4. **Bloque NULO:** 3–5 min de las actividades listadas, de forma natural.
5. Si el tiempo alcanza, repetir uno o dos ejercicios **con el otro brazo** (sirve para validar el espejado).

### 3.3 Volumen esperado
~20 sujetos × 6 ejercicios × 30 repeticiones ≈ 3,600 repeticiones, más ~1–1.5 h total de NULO. Es un dataset del mismo orden que el del paper.

### 3.4 Control de calidad tras cada sujeto
- Graficar las 6 señales de cada serie: sin cortes, sin saturación, marcas en su lugar.
- Contar las repeticiones visibles contra las marcadas.
- Guardar CSV crudo **y** una copia de respaldo. Nunca se edita el crudo; las correcciones van en un archivo de etiquetas aparte.

### 3.5 Formato de archivo
```
dataset/
  raw/S01_R_2026-10-10.csv     timestamp_ms, ax, ay, az, gx, gy, gz
  labels/S01_R_2026-10-10.csv  start_ms, end_ms, exercise_id, set, speed, rep_markers
  subjects.csv                 subject_id, sex, height_cm, dominant_arm, recorded_arm
```

## 4. Valores por defecto en la app

| ID | Ejercicio | Series × reps | Descanso |
|---|---|---|---|
| 1 | Flexión anterior | 3 × 10 | 45 s |
| 2 | Abducción | 3 × 10 | 45 s |
| 3 | Rotación externa | 3 × 12 | 45 s |
| 4 | Rotación interna | 3 × 12 | 45 s |
| 5 | Extensión de tríceps | 3 × 12 | 45 s |
| 6 | Estabilización escapular | 3 × 10 | 45 s |

Son valores de **demo**: el fisio los sobrescribe en cada prescripción.

## 5. Guion sugerido para la demo en vivo

1. El paciente demo (tú o un compañero) se coloca el reloj y abre la app.
2. Inicia la sesión: 2 ejercicios × 1 serie corta (5 repeticiones) para no alargar.
3. El contador sube en vivo en el celular (y en una pantalla espejo para el jurado).
4. A propósito, hacer un movimiento NULO (tomar agua): el contador **no** sube. Esto demuestra que no cuenta cualquier movimiento.
5. Terminar la sesión y mostrar cómo aparece en el dashboard del fisio junto al historial simulado.
