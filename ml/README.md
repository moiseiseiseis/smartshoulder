# Modelo de SmartShoulder (contexto/03)

Pipeline completo: dataset → ventanas → LOSO → contador → exportación int8 a la XIAO.

```
python -m pip install -r requirements.txt
```

## Días de captura: después de cada participante

```
python -m smartshoulder_ml.qc --subject S03            # resumen y lista de pendientes
python -m smartshoulder_ml.qc --subject S03 --plots    # además, una figura por serie en dataset/qc/
```

Revisa: muestras perdidas, saturación, que estén los 6 ejercicios × 3 ritmos y ≥ 3 min de NULO,
series sin movimiento, marcas de repetición contra las 10 del protocolo y lo que contaría el contador del firmware.

## Entrenar y evaluar

```
python -m smartshoulder_ml.train --model baseline                  # ~1 min: ¿el problema es fácil?
python -m smartshoulder_ml.train --model cnn --epochs 30           # LOSO completo (~75 s por sujeto)
python -m smartshoulder_ml.train --model cnn --folds 3 --epochs 15 # prueba rápida
python -m smartshoulder_ml.train --model cnn --skip-loso --export 1 --to-firmware
```

Por defecto lee `../dataset` (la carpeta que llena `tools/capture`). La exportación deja en `ml/models/model_vN/`:
`model.tflite`, `model_data.h`, `model_config.h` (normalización, espejado, cuantización y operaciones para el firmware)
y `model_card.json` (versión, commit, huella del dataset, sujetos y métricas LOSO, para ISO 14971).
`--to-firmware` copia los dos headers a `firmware/smartshoulder/`.

## Probar sin datos reales

```
python -m smartshoulder_ml.synthetic --out ../dataset_synth --subjects 8
python -m smartshoulder_ml.train --data ../dataset_synth --model baseline
python -m pytest -q
```

Los datos sintéticos **solo prueban que el código funciona**; sus métricas no dicen nada del modelo real.

## Reglas que no se rompen

- **Preprocesamiento idéntico** en Python (`preprocess.py`) y en el firmware: espejado, normalización y cuantización salen de `model_config.h`.
- **El contador** (`repcounter.py`) es copia exacta de `firmware/smartshoulder/repcounter.cpp`: si cambias uno, cambia el otro.
- **LOSO siempre**: nunca mezclar ventanas del mismo sujeto entre entrenamiento y prueba.
- **El eje de espejado** (`config.MIRROR_AXIS`) es provisional: se fija el primer día con `preprocess.estimate_mirror_axis()`,
  grabando el mismo ejercicio con cada brazo.
