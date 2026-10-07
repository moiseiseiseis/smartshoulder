# Herramienta de captura del dataset

Graba la señal del reloj y las etiquetas de cada serie con el formato de `contexto/05-specs-ejercicios-protocolo.md` §3.5.
Es solo para investigación: no forma parte de la app del paciente.

## Instalación (una vez)

```
python -m pip install bleak pyserial matplotlib pytest
```

## Uso

```
python app.py              # guarda en SmartShoulder/dataset/ (ignorado por git: tiene datos personales)
```

1. **Reloj:** Bluetooth → *Buscar* → *Conectar*. *Identificar* hace parpadear el LED azul. Respaldo: *Cable USB* y elegir el puerto COM.
2. **Participante:** el ID se propone solo (S01, S02…). Llena sexo, estatura y brazos → *Iniciar grabación*.
3. **Protocolo:** la cuadrícula marca con ✓ cada ejercicio × ritmo grabado y salta sola al siguiente pendiente.
4. **Serie:** `ESPACIO` inicia y termina la serie; `R` marca cada repetición (opcional; sirve para evaluar el contador).
   *Cancelar serie* no guarda la etiqueta; *Descartar última* borra la etiqueta de la última serie (el crudo nunca se borra).
5. Al final del participante: *Terminar grabación*.

Durante la grabación revisa el recuadro de estado: la frecuencia debe estar en ~50 Hz y las muestras perdidas en 0.

## Pruebas

```
python -m pytest -q
```
