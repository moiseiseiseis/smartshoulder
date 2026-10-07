# SmartShoulder — 03. Especificaciones del modelo embebido (TinyML)

**Versión:** 0.1
**Relacionado:** `02-specs-firmware-xiao.md` (dónde corre), `05-specs-ejercicios-protocolo.md` (de dónde salen los datos)

---

## 1. Qué tiene que resolver el modelo

Dos tareas, deliberadamente separadas:

| Tarea | Cómo se resuelve | Por qué así |
|---|---|---|
| **¿Qué ejercicio se está haciendo?** | Clasificador TinyML por ventana | Es un problema de patrón, ideal para una red pequeña |
| **¿Cuántas repeticiones?** | Algoritmo de señal (detección de picos) **condicionado** al ejercicio que detecta el clasificador | Más robusto y explicable que pedirle a la red que cuente; no requiere etiquetar cada repetición para entrenar |

La lógica de sesión (completa o incompleta) **no** es ML: es una comparación contra la prescripción.

**Referencia de factibilidad:** el paper de MDPI (ECA-ResNet1D-Lite, 13,612 parámetros, IMU de muñeca de 6 ejes a 50 Hz, 6 ejercicios de hombro, 99.1 % bajo leave-one-subject-out, 20 sujetos sanos). Es el techo de referencia, no una meta garantizada con datos propios.

## 2. Clases

| ID | Clase |
|---|---|
| 0 | `NULO` — reposo, transición, caminar, actividades cotidianas |
| 1 | Flexión anterior |
| 2 | Abducción |
| 3 | Rotación externa |
| 4 | Rotación interna |
| 5 | Extensión de tríceps (jalón) |
| 6 | Estabilización escapular (remo/retracción) |

El set final depende de la validación con el fisioterapeuta (doc 05). **La clase `NULO` es obligatoria:** sin ella, el modelo "ve" ejercicios todo el tiempo y el contador cuenta movimientos que no son ejercicio.

## 3. Datos y preprocesamiento

### 3.1 Entrada
- 6 canales: ax, ay, az (g) y gx, gy, gz (dps).
- 50 Hz, ventana de **2 s = 100 muestras** → tensor de entrada `[1, 100, 6]`.
- Paso de ventana: 0.5 s en inferencia; en entrenamiento se puede usar un paso menor para generar más ventanas.

### 3.2 Pipeline (idéntico en Python y en firmware)
1. Escalado a unidades físicas (g, dps) con las mismas constantes que el firmware.
2. **Espejado izquierda/derecha:** si el dispositivo va en la muñeca izquierda, invertir el signo de los ejes que corresponda para que el movimiento "se vea" como en la derecha. Los ejes exactos se determinan **empíricamente** el primer día: grabar el mismo ejercicio con cada brazo, comparar y fijar la regla. Esto evita entrenar dos modelos.
3. Normalización z-score por canal, con media y desviación estándar **del set de entrenamiento**, congeladas y copiadas a `config.h`.
4. Cuantización de entrada a int8 con la escala y el zero-point del modelo exportado.

### 3.3 Etiquetado
- A nivel serie: marcas de inicio y fin desde la app en modo investigador.
- Una ventana recibe la etiqueta del ejercicio si ≥ 80 % de sus muestras caen dentro de la serie; si no, se etiqueta `NULO`.
- Marcas por repetición (opcional): sirven para **evaluar** el contador, no para entrenar el clasificador.

### 3.4 Aumento de datos (solo entrenamiento)
- Ruido gaussiano pequeño.
- Escalado de amplitud (±10 %).
- Estiramiento temporal (±15 %; simula gente lenta o rápida).
- Rotación pequeña de ejes (±10°; simula el dispositivo un poco girado en la muñeca).

## 4. Arquitecturas candidatas

Probar en este orden y quedarse con la más simple que cumpla las metas:

| # | Modelo | Parámetros aprox. | Comentario |
|---|---|---|---|
| A | **Baseline:** features estadísticas por ventana (media, desviación estándar, mín, máx, energía por canal) + MLP pequeño o árbol | < 5 K | Rápido de entrenar; sirve para saber si el problema es fácil |
| B | **1D-CNN pequeña:** 3 bloques Conv1D (16–32 filtros, kernel 5) + GlobalAvgPool + Dense | 10–20 K | Candidato principal para Demo Day |
| C | **Inspirada en ECA-ResNet1D-Lite:** convoluciones depthwise separable + bloques residuales + atención de canal (ECA) | ~14 K | Replica la idea del paper, si B no alcanza |

Todas deben poder cuantizarse a **int8 completo** (pesos y activaciones) y usar solo operaciones soportadas por TFLite Micro (Conv1D se implementa como Conv2D con alto = 1).

## 5. Entrenamiento y evaluación

- **Stack:** Python, TensorFlow/Keras, NumPy, pandas, scikit-learn.
- **Validación: leave-one-subject-out (LOSO).** Nunca mezclar ventanas del mismo sujeto entre train y test: con datos de IMU eso infla la precisión de forma engañosa.
- **Métricas:**
  - Clasificación: accuracy, **F1 macro**, matriz de confusión (vigilar la confusión rotación interna/externa).
  - Conteo: error absoluto medio de repeticiones por serie y % de series con conteo exacto.
  - Sesión: % de sesiones clasificadas correctamente como completa o incompleta.
- **Metas para Demo Day** (propuestas, ajustables):
  - F1 macro ≥ 0.90 en LOSO.
  - Error de conteo ≤ 1 repetición en ≥ 90 % de las series.
  - Falsos positivos de ejercicio durante actividad `NULO` < 5 %.

## 6. Contador de repeticiones

1. Tomar la señal más informativa **por ejercicio** (definida empíricamente): p. ej. el giroscopio en el eje de rotación dominante para las rotaciones, o el ángulo de inclinación estimado del acelerómetro para flexión y abducción.
2. Filtro pasa-bajas (Butterworth de 2.º orden, ~2–3 Hz de corte).
3. Detección de picos con:
   - umbral mínimo de amplitud por ejercicio,
   - distancia mínima entre picos (p. ej. ≥ 1 s; una repetición de fisio rara vez dura menos),
   - histéresis para no contar ruido.
4. Solo se cuentan picos mientras el clasificador (suavizado) indica ese ejercicio con confianza ≥ umbral.
5. Los parámetros por ejercicio se guardan en una tabla en `config.h`, calibrada con los datos de captura.

## 7. Exportación al dispositivo

1. Keras → `TFLiteConverter` con cuantización int8 completa y un *representative dataset*.
2. `.tflite` → arreglo C (`xxd -i model.tflite > model_data.h`).
3. En el firmware: `MicroMutableOpResolver` con solo las operaciones usadas (ahorra flash).
4. **Presupuesto de recursos:**

| Recurso | Disponible | Meta |
|---|---|---|
| Flash del modelo | 1 MB total | < 100 KB |
| Tensor arena (RAM) | 256 KB total | < 64 KB |
| Latencia por ventana | — | < 50 ms |

### Ruta alternativa: Edge Impulse
Seeed tiene tutoriales de Edge Impulse con la XIAO nRF52840 Sense. Ventaja: captura, entrenamiento, cuantización y librería Arduino en una sola herramienta. Desventaja: menos control y menos "tuyo" técnicamente. Recomendación: usarla para un **primer prototipo rápido** de la tubería completa y luego migrar al pipeline propio en Python si da tiempo, o mantenerla si el resultado es bueno.

## 8. Versionado y trazabilidad

Cada modelo exportado se guarda con:
- versión (`model_v0.3`),
- hash del dataset y lista de sujetos usados,
- constantes de normalización,
- métricas LOSO,
- fecha y commit.

El firmware reporta la versión del modelo en `STATUS`, y la app la guarda en cada sesión. Esto también sirve para la documentación de gestión de riesgos (ISO 14971): saber con qué versión del algoritmo se generó cada dato.

## 9. Riesgos técnicos conocidos

| Riesgo | Mitigación |
|---|---|
| El dispositivo se coloca girado en la muñeca | Carcasa con orientación única (doc 06) + aumento de datos con rotación |
| Pacientes reales se mueven distinto que voluntarios sanos | Declararlo como limitación en Demo Day; validar después con datos clínicos |
| Estabilización escapular mueve poco la muñeca | Revisar con el fisio la variante (remo con banda); si no se detecta bien, sacarla del set inicial |
| Confusión rotación interna/externa | Revisar la matriz de confusión; usar el signo del giroscopio como feature explícita si hace falta |
