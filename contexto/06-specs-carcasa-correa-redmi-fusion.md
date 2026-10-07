# SmartShoulder — 06. Carcasa con anclaje para correas del Redmi Watch 5: investigación, especificaciones y modelado en Autodesk Fusion

**Versión:** 0.1. **Solo para prototipo y Demo Day; no es el diseño comercial.**
**Relacionado:** `02-specs-firmware-xiao.md` (componentes que van dentro), `03-specs-modelo-tinyml.md` (por qué importa la orientación)

---

## 1. Investigación: cómo se sujetan las correas del Redmi Watch 5

### 1.1 Lo que dice el fabricante (fuente confiable)
- **Redmi Watch 5 Active:** Xiaomi lo describe como diseño de *switch-lug* con **botón de liberación rápida**. Para quitar la correa se desliza el botón y se jala; para poner una nueva se **inserta la punta de la correa en el reloj y se empuja hasta oír un clic**. Ancho de la correa de TPU: **22 mm** (medido en la cola de la correa larga). Muñeca: 135–205 mm.
- **Redmi Watch 5 Lite:** mismo mecanismo de liberación rápida; Xiaomi reporta **20 mm** de ancho en la cola de la correa de TPU. Muñeca: 135–205 mm. Cuerpo del reloj: 48.1 × 39.2 × 10.6 mm.
- Xiaomi indica que estas correas **no son intercambiables con otros relojes Xiaomi**: el conector es propietario.

### 1.2 Lo que esto significa para tus correas
- Tus correas (Kuoaeaye, nylon con velcro) dicen ser compatibles con **5 Active y 5 Lite a la vez**, así que el conector debe ser el mismo para ambos, aunque el ancho de la cola de la correa original difiera.
- El conector es una **lengüeta moldeada** en la punta de la correa que entra en una ranura del cuerpo del reloj y se traba con un clic. **No** es el pasador de resorte estándar (spring bar) de 20/22 mm de los relojes tradicionales.
- **No existe un CAD público** del conector ni de la ranura. Las páginas tipo "wiki" de AliExpress que dan medidas son contenido generado para SEO y se contradicen entre sí; **no usarlas como fuente de medidas**.
- En Thingiverse, MakerWorld y Printables hay modelos de fundas protectoras y bases de carga para el Redmi Watch 5 Active (enlaces en Fuentes). Sirven como referencia visual de la forma del cuerpo y de dónde quedan las ranuras, pero no traen la geometría interna del seguro.

### 1.3 Conclusión
La única fuente confiable de medidas **son tus propias correas**. La ruta es:
1. medir el conector con vernier,
2. diseñar una ranura receptora en la carcasa,
3. imprimir **cupones de prueba** de tolerancia antes de imprimir la carcasa completa.

## 2. Medición del conector (hazlo primero)

**Herramienta:** vernier digital (~$150–300 MXN si no tienes uno; en el laboratorio seguro hay). Mide 3 veces cada cota y usa el promedio.

Toma una foto del conector desde arriba, de lado y de frente junto a una regla, y llena la tabla:

| Cota | Descripción | Valor (mm) |
|---|---|---|
| `strap_w` | Ancho de la lengüeta que entra en el reloj | ____ |
| `strap_t` | Espesor de la lengüeta | ____ |
| `strap_l` | Largo que se inserta (desde la punta hasta donde empieza el nylon) | ____ |
| `latch_pos` | Distancia de la punta al seguro, muesca o botón | ____ |
| `latch_w`, `latch_h` | Tamaño del seguro o muesca | ____ |
| `strap_body_w` | Ancho del nylon justo después del conector | ____ |
| Forma de la punta | Recta, redondeada o con chaflán | ____ |
| ¿Tiene orificio pasante? | Sí/No y diámetro (útil para fijarla con un perno) | ____ |

Haz también un **calco**: presiona el conector sobre plastilina o toma una foto cenital con escala, e impórtala como *Canvas* en Fusion (sección 5) para copiar el contorno.

## 3. Especificaciones de la carcasa

### 3.1 Lo que va adentro

| Componente | Medidas aprox. | Nota |
|---|---|---|
| XIAO nRF52840 Sense | 21 × 17.8 mm, ~4–5 mm de alto con componentes (medir) | Seeed publica el modelo 3D de la versión Sense en su wiki: descárgalo |
| Batería LiPo plana | p. ej. 402030 (~4 × 20 × 30 mm) o 502030 | Medir la que compres; dejar +0.5 mm de holgura (las LiPo se hinchan un poco) |
| Cables BAT+/BAT− (y zócalo JST si lo usas) | — | Canal para cables, sin pellizcarlos |

### 3.2 Requisitos

| # | Requisito | Valor guía |
|---|---|---|
| R1 | **Orientación única de la placa:** cavidad asimétrica o con tope, para que la XIAO solo entre en una posición | Crítico para el modelo TinyML (doc 03) |
| R2 | **Marca de orientación** en la tapa ("▲ dedos") | Grabado de 0.4–0.6 mm de profundidad |
| R3 | Acceso al **USB-C** sin abrir la carcasa | Ventana de ~9.5 × 3.8 mm (medir el conector) + 0.3 mm de holgura |
| R4 | LED visible | Orificio de 1.5–2 mm o pared delgada traslúcida sobre el LED RGB |
| R5 | Acceso al botón **reset** | Orificio de 1.5 mm para presionar con un clip |
| R6 | Placa fija (que no vibre) | Si la placa se mueve dentro de la carcasa, mete ruido al IMU. Usar costillas de presión o 2 tornillos M2 |
| R7 | Paredes | 1.6–2.0 mm (4–5 perímetros con boquilla de 0.4) |
| R8 | Cierre | Tapa con 2–4 tornillos M2 (más simple y desarmable) o *snap-fit* |
| R9 | **Receptores de correa** en ambos extremos, alineados con `strap_w` | Ver sección 4 |
| R10 | Cara inferior (contra la piel) | Lisa, con bordes redondeados (filete ≥ 1 mm) y ligeramente curva si se puede (radio ~40–50 mm, como la muñeca) |
| R11 | Tamaño exterior objetivo | ~45 × 28 × 12–14 mm, "como un reloj grueso". El ancho lo fija sobre todo `strap_w` + paredes |
| R12 | Material | **PETG** preferido (aguanta más calor que PLA, por ejemplo dentro de un carro, y es más tenaz). PLA sirve para las primeras pruebas |

## 4. Diseño del receptor de correa (lo crítico)

Tres opciones, de la más fácil a la más fiel:

### Opción A — Ranura de fricción + perno pasante (recomendada para Demo Day)
- Ranura rectangular de `strap_w + tol` × `strap_t + tol`, profundidad `strap_l`.
- Un perno transversal (tornillo M2, o un pin de clip de 1–1.5 mm) atraviesa la carcasa **y** la lengüeta (perfora la lengüeta si no tiene orificio) para que no se salga.
- Ventajas: robusta, no depende de replicar el seguro, se arma en minutos.
- Desventaja: cambiar la correa toma un minuto con desarmador, cosa que en la demo no importa.

### Opción B — Ranura con resalte de retención
- Igual que A, pero en lugar del perno, un resalte o diente impreso que encaja en la muesca del seguro (`latch_pos`) y retiene por forma.
- Depende mucho de la precisión de la impresora; requiere iteración.

### Opción C — Réplica del mecanismo de clic con botón
- Copia del seguro deslizable del reloj. Varias piezas móviles pequeñas, difícil en FDM a esta escala. **No vale la pena para Demo Day.**

### Tolerancias (FDM)
Imprime **primero un cupón de prueba**: un bloque pequeño con 4 ranuras de holgura distinta. Los valores varían según la impresora, así que hay que probarlos.

| Ranura | Holgura sobre `strap_w` y `strap_t` |
|---|---|
| 1 | +0.10 mm |
| 2 | +0.20 mm |
| 3 | +0.30 mm |
| 4 | +0.40 mm |

Prueba la lengüeta en cada una y quédate con la que **entre con un poco de presión** sin forzar. Ese valor es el parámetro `tol` de toda la carcasa.

## 5. Cómo modelarlo en Autodesk Fusion (paso a paso)

### 5.1 Preparación
1. **Licencia:** Fusion tiene licencia gratuita para estudiantes y educadores (con correo de UDG), o la versión personal.
2. Crea el proyecto `SmartShoulder` y el diseño `Carcasa_v1`.
3. **Parámetros de usuario** (Modify → Change Parameters). Todo el diseño depende de ellos; si una medida cambia, se actualiza solo:
```
tol        = 0.2 mm     (resultado del cupón)
wall       = 1.8 mm
xiao_l     = 21 mm      xiao_w = 17.8 mm   xiao_h = 4.5 mm (medir)
bat_l      = 30 mm      bat_w  = 20 mm     bat_h  = 4 mm   (medir)
strap_w    = __ mm      strap_t = __ mm    strap_l = __ mm  (de la tabla de la sección 2)
corner_r   = 3 mm
```

### 5.2 Componentes de referencia (no se imprimen)
4. Descarga el STEP de la XIAO nRF52840 Sense del wiki de Seeed, súbelo al proyecto (**Data Panel → Upload**) y arrástralo al diseño (**clic derecho → Insert into Current Design**). Si no lo encuentras, modela un **dummy**: caja de `xiao_l × xiao_w × xiao_h` con un bloque para el USB-C.
5. Dummy de batería: caja de `bat_l × bat_w × bat_h`.
6. **Insert → Canvas:** la foto cenital del conector de la correa, calibrada con la regla (clic derecho → Calibrate), para calcar el contorno.
7. Acomoda placa y batería apiladas (batería abajo, placa arriba, o lado a lado si quieres una carcasa más delgada y larga) y deja ~0.5 mm de holgura entre ellas.

### 5.3 Cuerpo de la carcasa
8. **Sketch** en el plano XY: rectángulo exterior que envuelva los componentes + `wall` + holguras. Redondea las esquinas con `corner_r`.
9. **Extrude** a la altura total.
10. **Shell** (Modify → Shell) seleccionando la cara superior, espesor `wall`: queda una caja abierta.
11. **Fillet** en las aristas exteriores (1–2 mm) y en la base que toca la piel.

### 5.4 Cavidades e interior
12. Sketch en el piso interior: contorno de la XIAO + `tol`, con un **tope o chaflán en una sola esquina** (R1, orientación única). Extrude hacia arriba para crear las paredes de alojamiento (costillas de 1 mm).
13. Cama de la batería y canal para cables.
14. Si usas tornillos: **Create → Boss** (o cilindros extruidos) para tornillos M2: diámetro exterior de 4.5 mm y orificio de 1.7 mm para autorroscante en plástico.

### 5.5 Aberturas
15. Sketch en la pared donde queda el USB-C, alineado con el dummy: rectángulo de USB-C + `tol` → **Extrude Cut** a través de la pared.
16. Orificios del LED y del reset: círculos → Extrude Cut.

### 5.6 Receptores de correa (Opción A)
17. En cada cara corta de la carcasa: sketch de un rectángulo de `strap_w + tol` × `strap_t + tol`, centrado → **Extrude Cut** con profundidad `strap_l`.
    - Si la carcasa no es lo bastante ancha, ensancha esos extremos con "orejas" (*lugs*) extruidas hacia afuera, como las de un reloj.
18. Perno pasante: sketch en la cara lateral, un círculo de 2.2 mm (para M2) que atraviese la oreja a la mitad de `strap_l` → Extrude Cut a través de todo.
19. Chaflán de 0.3–0.5 mm en la boca de la ranura, para que la lengüeta entre fácil.

### 5.7 Tapa
20. **Split Body** con un plano a la altura del borde (o modela la tapa como componente aparte).
21. Agrega un **labio** de 1 mm en la tapa que entre en la caja (holgura `tol`) para que cierre bien y no se desalinee.
22. Grabado de la flecha de orientación en la tapa: sketch de texto o triángulo → Extrude Cut de 0.5 mm.
23. Orificios de tornillos de la tapa (2.2 mm, avellanados si quieres que queden al ras).

### 5.8 Verificación en Fusion
24. **Inspect → Interference:** que nada choque con los dummies.
25. **Inspect → Section Analysis:** corte a la mitad para revisar paredes y holguras.
26. Activa y desactiva los dummies para revisar visualmente.

### 5.9 Exportar e imprimir
27. Clic derecho en cada cuerpo (caja y tapa) → **Save As Mesh** → 3MF o STL.
28. **Orientación de impresión:** caja con la base en la cama; tapa con la cara exterior abajo (para que el grabado salga limpio).
29. Ajustes sugeridos: capa de 0.16–0.2 mm, 4 perímetros, relleno de 30–40 %, PETG. Las ranuras de la correa deben quedar con su eje horizontal; si quedan verticales se deforman. Si alguna requiere puentes largos, ajústalo en el diseño.

## 6. Orden de trabajo recomendado

1. Medir el conector (sección 2).
2. Modelar e imprimir **solo el cupón de tolerancias** (~15 min de impresión).
3. Definir `tol` y medir los componentes reales (XIAO y batería).
4. Modelar la carcasa v1 con parámetros.
5. Imprimir y probar el ensamble: placa, batería, cierre y correas.
6. **Prueba de movimiento:** con la XIAO dentro, en modo captura, sacudir el brazo y confirmar que no aparecen picos raros por placa suelta.
7. Ajustar → v2 → imprimir en PETG final para Demo Day.

## 7. Nota para la versión comercial (no ahora)

La interfaz con correas de Redmi es un atajo de prototipo. Para comercializar no conviene depender del conector propietario de otra marca. La versión de producto usaría un estándar abierto (pasadores de resorte de 20/22 mm, o ranuras tipo NATO para correa pasante), y así cualquier correa del mercado sería compatible.

---

## Fuentes

- [REDMI Watch 5 Active FAQ — Xiaomi Global (mecanismo switch-lug, 22 mm, compatibilidad)](https://www.mi.com/global/support/faq/details/KA-483511/)
- [How to replace the strap of the REDMI Watch 5 Lite — Xiaomi Global (liberación rápida, 20 mm)](https://www.mi.com/global/support/faq/details/KA-485253/)
- [REDMI Watch 5 Lite Specs — Xiaomi Global (dimensiones del cuerpo)](https://www.mi.com/global/product/redmi-watch-5-lite/specs/)
- [Xiaomi Redmi Watch 5 Active — Protector Hard Case (Thingiverse, referencia de forma)](https://www.thingiverse.com/thing:6823952)
- [Support Redmi Watch 5 Active (MakerWorld)](https://makerworld.com/en/models/997526-support-redmi-watch-5-active)
- [Stand Redmi Watch 5 (Printables)](https://www.printables.com/model/1085787-stand-redmi-watch-5)
- [Seeed Studio XIAO nRF52840 Series — Wiki (medidas de la placa y recursos 3D)](https://wiki.seeedstudio.com/XIAO_BLE/)
