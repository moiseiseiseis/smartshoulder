# Rumbo Rehab — 13. Guía paso a paso para grabar el dataset

**Versión:** 1.0 (18 oct 2026)
**Para quién:** quien graba (Moisés) y quien ayuda a marcar repeticiones.
**Relacionado:** `05` (ejercicios y protocolo), `11` (colocación y calibración), `tools/capture/README.md`, `ml/README.md`

Ten esta guía abierta o impresa junto a la laptop.

---

## 0. Meta

| | |
|---|---|
| **Participantes** | Mínimo **8**, ideal **12–15** (sanos, variedad de sexo, estatura y complexión) |
| **Tiempo por persona** | 30–40 min |
| **Por persona se graba** | 6 ejercicios × 3 series de 10 repeticiones (normal, lenta, rápida) + 3–5 min de NULO |
| **Fecha límite** | 19 oct en la noche (el 20 se entrena el modelo) |

---

## 1. Antes de empezar el día (una vez)

- [ ] **Bluetooth de la PC encendido** (Configuración → Bluetooth y dispositivos). Windows lo apaga solo a veces.
- [ ] **Reloj cargado:** más de 50 %. Se carga por USB-C dentro de la carcasa.
- [ ] Laptop conectada a la corriente y con la suspensión desactivada.
- [ ] Banda elástica y anclaje de puerta (para los ejercicios 3–6).
- [ ] Formatos de **consentimiento informado** impresos.
- [ ] Toallitas con alcohol para limpiar la carcasa y la correa entre personas.
- [ ] Una persona que ayude a marcar repeticiones (opcional pero muy útil, ver §5).

---

## 2. Abrir la herramienta y conectar el reloj

1. Abre una terminal en `C:\Proyectos\SmartShoulder` y corre:
   ```
   python tools/capture/app.py
   ```
2. Recuadro **1. Reloj**: deja **Bluetooth** seleccionado → **Buscar** → aparece **RR-54F5** en la lista → **Conectar**.
3. Revisa la línea debajo de los botones: debe decir **"Conectado · fw 2 · … · batería XX%"**.
4. Si dudas de cuál reloj es, **Identificar (LED)** hace parpadear la luz azul.

> Si no aparece el reloj: revisa el Bluetooth de la PC, acerca el reloj y vuelve a tocar **Buscar**.
> Respaldo: conecta el reloj por USB, elige **Cable USB** y el puerto **COM5**.

---

## 3. Con cada participante

### 3.1 Antes de grabar

1. **Consentimiento informado** firmado. Explícale que se graban solo movimientos del reloj, con un ID anónimo.
2. **Limpia** la carcasa y la correa.
3. **Coloca el reloj:**
   - En la **muñeca derecha** (salvo que se indique otra, ver §6).
   - **Flecha ▲ hacia el pulgar**, con el **conector USB-C del lado del pulgar**.
   - 1–2 cm arriba del hueso de la muñeca, **ajustado sin apretar**: que no gire alrededor de la muñeca.
4. Explica y **demuestra** los 6 ejercicios (doc 05 §2). Que haga **una serie de práctica** de cada uno **sin grabar**.

### 3.2 Datos del participante (recuadro 2)

| Campo | Qué poner |
|---|---|
| **ID anónimo** | Se propone solo (S01, S02…). No lo cambies salvo que sea necesario |
| **Sexo** | F / M / Otro |
| **Estatura (cm)** | Número, p. ej. 168 |
| **Brazo dominante** | R (derecho) / L (izquierdo) |
| **Brazo que se graba** | **R** casi siempre (ver §6) |

Anota en papel la relación ID ↔ nombre y guárdala **aparte** del dataset; el dataset solo lleva el ID.

### 3.3 Iniciar la grabación con la referencia de orientación

1. Pide al participante que se ponga **de pie, con el brazo colgando quieto y relajado**.
2. Toca **Iniciar grabación**.
3. Que se quede **5 segundos completamente quieto**. Cuenta en voz alta "cinco, cuatro, tres, dos, uno".
4. Listo: ya puede moverse. Esos 5 s sirven para verificar que el reloj está bien puesto.

> Si se te olvida, termina la grabación y empiézala de nuevo: se crea otro archivo y no se pierde nada.

### 3.4 Grabar cada serie

La cuadrícula **3. Protocolo** muestra cada ejercicio × ritmo; la celda en azul es la que sigue, y la herramienta avanza sola a la siguiente pendiente.

Para **cada serie**:
1. Que el participante tome la **posición inicial** y se prepare.
2. **Barra espaciadora** (o el botón grande) → **"● GRABANDO"** se pone en rojo.
3. Hace **10 repeticiones** al ritmo indicado.
4. Cuando **termina la última y regresa a la posición inicial**: **barra espaciadora** otra vez para cerrar la serie.
5. Descansa lo que necesite (no se graba como ejercicio, y sirve de "NULO" natural).

**Ritmos:**

| Ritmo | Subir | Bajar | Cómo decirlo |
|---|---|---|---|
| **Normal** | ~2 s | ~2 s | "Uno-dos arriba, uno-dos abajo" |
| **Lenta** | ~3 s | ~3 s | "Muy despacio y controlado" |
| **Rápida** | ~1 s | ~1 s | "Ágil pero controlado, **sin aventar el brazo**" |

> Nunca movimientos bruscos: en la prueba del 7 oct el giro llegó al máximo que mide el sensor (571 °/s) y esa señal no sirve. Una rehabilitación real está entre 60 y 120 °/s.

**Orden y montaje:**

| # | Ejercicio | Banda | Puntos clave |
|---|---|---|---|
| 1 | Flexión anterior | — | Brazo al frente, codo estirado, subir y bajar controlado |
| 2 | Abducción | — | Brazo por el costado, hasta la altura indicada |
| 3 | Rotación externa | Anclada **del lado contrario**, a la altura del codo | Codo pegado al costado a 90°, girar hacia afuera |
| 4 | Rotación interna | Anclada **del mismo lado** | Codo pegado, girar hacia el abdomen |
| 5 | Extensión de tríceps | Anclada **arriba** (marco de puerta) | Codos pegados, estirar hacia abajo y regresar a 90° |
| 6 | Estabilización escapular (remo) | Anclada **al frente**, a la altura del pecho | Codos atrás junto al cuerpo, juntar omóplatos, sostener 1–2 s |

### 3.5 Bloque NULO (al final, 3–5 min)

1. Toca la celda **"0. NULO (3–5 min)"** de la cuadrícula.
2. **Barra espaciadora** para iniciar.
3. Que haga actividades cotidianas, **de forma natural**, cambiando cada 20–30 s:
   - parado y sentado con el brazo quieto,
   - caminar balanceando los brazos,
   - usar el celular, tomar un vaso de agua, peinarse, rascarse la cabeza,
   - acomodar la banda, sacudir el brazo.
4. A los 3–5 min, **barra espaciadora** para cerrar.

> El NULO enseña al modelo a **no** contar lo que no es ejercicio. Es tan importante como los ejercicios.

### 3.6 Terminar

1. Toca **Terminar grabación**. La bitácora muestra muestras, perdidas y series.
2. Corre el **control de calidad** (§7) **antes de quitarle el reloj**: si algo salió mal, se repite esa serie en el momento.
3. Quita el reloj y límpialo.

---

## 4. Qué vigilar mientras grabas

El recuadro de estado (abajo a la izquierda) y la línea del recuadro **1. Reloj** deben mostrar:

| Indicador | Bien | Si no |
|---|---|---|
| **Frecuencia** | ~50 Hz | Si baja de 45 Hz: acerca la laptop al participante (menos de 3 m, sin cuerpos de por medio) |
| **Perdidas** | 0 o casi 0 | Igual que arriba |
| **Batería** (recuadro 1. Reloj) | Más de 20 % | Si baja de 20 %, termina y carga el reloj antes del siguiente participante |

La **gráfica** debe moverse con cada repetición. Si se queda plana, el reloj se desconectó.

---

## 5. Marcar repeticiones con la tecla R (opcional, muy útil)

Sirve para medir qué tan bien cuenta el reloj. Si tienes un ayudante:
- Mientras la serie está grabando, el ayudante presiona **R** **cada vez que el brazo regresa a la posición inicial** (al final de cada repetición).
- Siempre en el mismo momento del movimiento.
- Si se equivoca, no pasa nada: al terminar la serie se puede **Descartar última** y repetirla.

Sin ayudante, no marques R: el sistema asume las 10 repeticiones del protocolo.

---

## 6. Brazo izquierdo y espejado

- **Participante 1 (tú):** al terminar tu grabación completa con el brazo derecho, haz **otra grabación corta** con el reloj en la **muñeca izquierda** (flecha hacia el pulgar, USB-C del lado del pulgar):
  - en el recuadro 2, **Brazo que se graba = L** (el mismo ID S01);
  - 5 s colgando quieto, luego **rotación externa normal** y **flexión normal**, una serie de cada una;
  - **Terminar grabación**.

  Con eso se fija el eje de espejado.
- **De los demás participantes**, 2 o 3 pueden repetir lo mismo con el brazo izquierdo si hay tiempo. Sirve para validar el espejado.
- Si un participante es zurdo, graba igual el brazo derecho; solo anota su brazo dominante.

---

## 7. Control de calidad después de cada participante

En otra terminal:
```
cd C:\Proyectos\SmartShoulder\ml
python -m rumbo_ml.qc --subject S01 --plots
```

Revisa el final: **"✓ Sin problemas"** o la lista **"Revisar:"**.

| Si dice… | Qué hacer |
|---|---|
| **faltan: …** | Grabar las series que faltan (nueva grabación, mismo ID) |
| **serie muy corta** / **casi sin movimiento** | Repetir esa serie con movimiento completo |
| **el contador no coincide** | No es grave para el dataset; anotarlo |
| **no empezó con 5 s de brazo colgando quieto** | En la siguiente grabación no olvidarlo |
| **el reloj parece girado X°** | Revisar la colocación (flecha hacia el pulgar) y repetir la grabación |
| **muestras perdidas** / **saturación** | Acercar la laptop / pedir movimientos más controlados y repetir |

Las figuras quedan en `dataset/qc/`: una por serie, para revisar a ojo que se vean las 10 repeticiones.

O simplemente dime **"revisa S01"** y lo reviso yo.

---

## 8. Si algo falla

| Problema | Solución |
|---|---|
| **Se desconectó el reloj a media grabación** | La herramienta la termina sola y avisa. Lo grabado se conserva. **Conectar** de nuevo → **Iniciar grabación** (mismo ID; se crea otro archivo) → 5 s colgando → grabar **solo lo que faltaba**. La cuadrícula empieza vacía en el archivo nuevo: guíate por la bitácora o por el control de calidad |
| **Una serie salió mal** (se equivocó, se trabó) | Si todavía está grabando: **Cancelar serie** (no guarda la etiqueta). Si ya la cerraste: **Descartar última**. Luego vuelve a seleccionar esa celda y repítela |
| **El reloj no aparece al buscar** | Bluetooth de la PC encendido; reloj cargado; acércalo; **Buscar** otra vez |
| **La herramienta se cerró** | Lo grabado hasta ese momento ya está guardado (se escribe muestra por muestra). Abre de nuevo y sigue con una grabación nueva |

---

## 9. Al final del día (obligatorio)

0. **Apaga el reloj:** botón **Apagar reloj** en la herramienta (tres destellos rojos). Para encenderlo, **conéctalo al USB-C** (de paso se carga) o presiona el reset por el orificio de la carcasa. Si se te olvida, se apaga solo a los 15 min sin conexión.
1. **Respaldo:** copia la carpeta completa `C:\Proyectos\SmartShoulder\dataset\` a un **disco externo o un Drive privado**. El dataset **no se sube a git** (tiene datos personales): si no lo respaldas, solo existe en la laptop.
2. Guarda los consentimientos firmados y la hoja ID ↔ nombre **separados** del dataset.
3. Avísame cuántos participantes llevas; con 3–4 ya entreno una primera versión para ver si los datos van bien.

---

## 10. Resumen en una tarjeta

```
CONECTAR      python tools/capture/app.py → Bluetooth → Buscar → RR-54F5 → Conectar
COLOCAR       Muñeca derecha · flecha ▲ al PULGAR · USB-C al pulgar · ajustado sin apretar
DATOS         ID automático · sexo · estatura · dominante · brazo grabado = R
INICIAR       Brazo colgando → "Iniciar grabación" → 5 s QUIETO
CADA SERIE    ESPACIO → 10 repeticiones → ESPACIO       (R = marcar repetición, opcional)
RITMOS        normal 2s/2s · lenta 3s/3s · rápida 1s/1s controlada
ORDEN         1 flexión · 2 abducción · 3 rot. externa · 4 rot. interna · 5 tríceps · 6 remo
NULO          celda 0 → ESPACIO → 3–5 min de vida cotidiana → ESPACIO
TERMINAR      "Terminar grabación" → python -m rumbo_ml.qc --subject SXX --plots
FIN DEL DÍA   Respaldar dataset/
```
