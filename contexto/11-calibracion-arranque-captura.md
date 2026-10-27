# Rumbo Rehab — 11. Calibración y arranque de la captura

**Versión:** 0.1 (12 oct 2026)
**Pregunta que responde:** ¿hay que calibrar algo antes de empezar a grabar el dataset?
**Respuesta corta:** **no.** Solo hay que verificar la orientación del reloj y grabar el espejado al inicio. Todo lo demás se calibra con los datos.
**Relacionado:** `03-specs-modelo-tinyml.md`, `05-specs-ejercicios-protocolo.md`, `ml/README.md`

---

## 0. Regla de colocación del reloj

En las dos muñecas: **flecha ▲ hacia el pulgar**, con el **conector USB-C del lado del pulgar** (regla fijada el 18 oct 2026, igual en ambos brazos). Ajustado sin apretar, 1–2 cm arriba del hueso de la muñeca. **Todos los participantes y pacientes igual**; si alguien lo pone al revés, la señal queda girada 180° y el control de calidad lo marca.

## 1. Qué significa "calibrar" en este proyecto

| Qué | ¿Antes de capturar? | Cuándo y cómo |
|---|---|---|
| **Umbrales del contador de repeticiones** | **No** | Se calibran **con** los datos capturados. La herramienta de captura guarda la señal cruda, así que la captura no depende de ningún umbral. El control de calidad (`python -m rumbo_ml.qc`) y la evaluación del contador (`train`) muestran cuánto acierta y permiten ajustarlo. |
| **Eje de espejado** (brazo izquierdo ↔ derecho) | ✅ **Hecho (18 oct)** | **Eje Y**, confirmado con S01 (protocolo completo con cada brazo): rotación externa y flexión eligen Y con margen amplio, y la gravedad con el brazo colgando es espejo exacto (y −0.94 vs +0.93). |
| **Orientación de la placa en la carcasa** | **Sí, pero es solo verificarla** | Lo único crítico: la XIAO debe ir **siempre en la misma posición** dentro de la carcasa y la carcasa siempre igual en la muñeca (flecha ▲ hacia el pulgar, USB-C del lado del pulgar). Con la carcasa nueva se comprueba en 2 minutos. |
| **Sesgo del giroscopio** (~5 °/s medido el 6 oct) | **No** | La normalización del modelo lo absorbe. |
| **Medidor de batería** | **No** | Con la LiPo soldada: una medición con multímetro y se ajusta `VBAT_CAL` en `firmware/rumbo/power.cpp` (5 min). |

## 2. Arranque del primer día de captura

1. **Verificar la orientación** (2 min): reloj puesto, brazo colgando quieto 5 s; revisar en la gráfica de la herramienta de captura que la gravedad cae en el eje esperado. Anotar el resultado como referencia.
2. **Grabar el espejado** (10 min): el mismo ejercicio (p. ej. rotación externa, 1 serie) con el brazo derecho y luego con el izquierdo, misma persona.
3. **Primer participante completo** y correr el control de calidad antes de seguir con el segundo.

## 3. En cada participante

- Empezar cada grabación con **5 s de brazo colgando quieto**. Se agregará al control de calidad una revisión que compare esa referencia de gravedad y avise si el reloj quedó girado.
- Recordar el ritmo del protocolo (**~2 s subir, ~2 s bajar**). En la prueba del 7 oct el giro llegó a 571 °/s (el máximo del sensor), muy por encima de los 60–120 °/s de una rehabilitación. El control de calidad marca la saturación.
- Correr `qc --subject SXX` al terminar a cada participante.
