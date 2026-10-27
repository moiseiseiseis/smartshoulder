# Requisitos normativos del prototipo — Rumbo Rehab

**Fecha:** 27 oct 2026
**Uso:** cruzar contra el modelado 3D de la carcasa, la correa, la electrónica y el firmware. Cada requisito tiene un ID (`RR-REQ-…`) para referenciarlo desde commits, issues o el CAD.
**Relacionado:** `14-estado-tecnico.md`, ficha regulatoria preliminar (hipótesis Clase II).

> **Aviso.** Este documento traduce normas a requisitos de diseño, pero no sustituye el texto de las normas (IEC/ISO son de pago) ni la opinión de un asesor regulatorio. Los números de cláusula y los valores marcados con ⚠ hay que verificarlos contra la edición vigente de cada norma antes de usarlos como criterio formal. Para el Demo Day y el piloto, esto funciona como **entradas de diseño**, no como certificación.

---

## 0. Supuestos del producto que definen qué aplica

| Supuesto | Por qué importa |
|---|---|
| Equipo con **alimentación interna** (LiPo), carga por USB-C | Define los requisitos de seguridad eléctrica y de carga |
| **Se porta en la muñeca**: la cara trasera y la correa tocan piel intacta | La zona de contacto es una **parte aplicada**; probable tipo BF ⚠ |
| Uso principal en **domicilio**, por personas sin formación técnica (adultos mayores) | Aplica IEC 60601-1-11 (entorno doméstico) además de la 60601-1 |
| Radio **BLE 2.4 GHz** (nRF52840) | EMC (IEC 60601-1-2) y homologación IFT |
| Los relojes **rotan entre pacientes** (comodato) | Limpieza entre pacientes, identificación de cada unidad y emparejamiento correcto |
| Sesiones de ~30 min, varias por semana, durante 6–16 semanas | Exposición acumulada de piel >24 h → biocompatibilidad "prolongada" ⚠ |

---

## 1. Seguridad eléctrica y térmica — IEC 60601-1 (+ IEC 60601-1-11)

| ID | Componente | Requisito de diseño | Cómo verificar | Fase |
|---|---|---|---|---|
| RR-REQ-ELEC-01 | Firmware + instructivo | **No se usa en el paciente mientras carga.** El firmware bloquea o advierte el inicio de sesión si detecta VBUS (USB conectado), y el instructivo lo dice | Prueba: conectar USB e intentar iniciar sesión | Piloto |
| RR-REQ-ELEC-02 | Carcasa | Ningún conductor expuesto en la cara de contacto con piel: pads, pines y soldaduras quedan dentro de la carcasa | Inspección visual + continuidad con multímetro desde la cara trasera | Demo |
| RR-REQ-ELEC-03 | Carcasa | El puerto USB-C (carcasa metálica accesible) queda en un lateral, **no** en la cara de piel | Revisión del CAD | Demo |
| RR-REQ-ELEC-04 | Accesorio | El cargador que se entregue con el kit es una fuente USB **certificada** (NOM-001-SCFI vigente / IEC 62368-1). No se entregan fuentes genéricas | Ficha y certificado de la fuente | Piloto |
| RR-REQ-TERM-01 | Carcasa + batería | Temperatura de la superficie en contacto con piel **≤ 41 °C** durante una sesión y durante la carga. Por encima de 41 °C la norma exige advertirlo; el máximo para contacto ≥ 10 min es 43 °C (tabla 24) ⚠ | Termopar en la cara trasera: sesión de 30 min + carga completa | Piloto |
| RR-REQ-MEC-01 | Carcasa | Sin bordes, esquinas ni rebabas filosas (cl. 9.3) | Inspección táctil tras impresión y post-proceso | Demo |

## 2. Batería — IEC 62133-2 y transporte

| ID | Componente | Requisito de diseño | Cómo verificar | Fase |
|---|---|---|---|---|
| RR-REQ-BAT-01 | Batería | Celda con certificación **IEC 62133-2** y circuito de protección (PCM) integrado. Pedir el certificado al proveedor | Documento del proveedor | Piloto |
| RR-REQ-BAT-02 | Carcasa | Holgura para hinchamiento de la celda (~10% del espesor) ⚠; la carcasa ni la correa presionan la celda | Medición en CAD | Piloto |
| RR-REQ-BAT-03 | Electrónica | Alivio de tensión en los cables de la batería; las soldaduras no trabajan a flexión. **Relación directa con el problema actual de carga** | Prueba de tirón suave + revisión tras 50 ciclos de abrir y cerrar | Demo |
| RR-REQ-BAT-04 | Firmware | Corte por bajo voltaje (hoy 3.35 V) y apagado seguro. Calibrar `VBAT_CAL` | Medición contra multímetro | Demo |
| RR-REQ-BAT-05 | Firmware / electrónica | No cargar fuera del rango de temperatura de la celda (típico 0–45 °C ⚠). Revisar si el cargador de la XIAO lo controla; si no, documentarlo como riesgo | Hoja de datos del cargador y de la celda | Producto |
| RR-REQ-BAT-06 | Logística | Envío de unidades con batería de litio: celdas con reporte UN 38.3 | Documento del proveedor | Piloto |

## 3. Compatibilidad electromagnética — IEC 60601-1-2 (entorno doméstico)

| ID | Componente | Requisito de diseño | Cómo verificar | Fase |
|---|---|---|---|---|
| RR-REQ-EMC-01 | Carcasa | Sin metal expuesto que lleve descargas electrostáticas a la placa (botones, tornillos). Niveles de inmunidad a ESD del entorno doméstico: ±8 kV contacto, ±15 kV aire ⚠ | Prueba en laboratorio acreditado | Producto |
| RR-REQ-EMC-02 | Electrónica | Emisiones: CISPR 11, Grupo 1, Clase B ⚠ | Laboratorio | Producto |
| RR-REQ-EMC-03 | Firmware + app | Coexistencia inalámbrica: la sesión tolera pérdida de BLE sin perder repeticiones. Ya existe el búfer de 256 eventos (`SYNC_EVENTS`) | Prueba con WiFi y otros dispositivos BLE cerca | Piloto |

## 4. Radio — IFT (Disposición Técnica IFT-008-2015)

| ID | Componente | Requisito de diseño | Cómo verificar | Fase |
|---|---|---|---|---|
| RR-REQ-RF-01 | Electrónica | Confirmar si el módulo o la tarjeta XIAO nRF52840 tiene **certificado de homologación IFT**. Si no, el producto final necesita homologación (IFT-008-2015, banda 2400–2483.5 MHz) | Buscar el certificado en el IFT o pedirlo a Seeed | Piloto |
| RR-REQ-RF-02 | Carcasa | Sin metal, pintura metálica ni insertos cerca de la antena. La zona de la antena va con plástico limpio | Revisión del CAD + prueba de alcance BLE con el reloj puesto | Demo |
| RR-REQ-RF-03 | Etiqueta | Espacio en la etiqueta o el empaque para el **Sello IFT** y el número de certificado | Revisión del diseño de la etiqueta | Producto |

## 5. Mecánica y entorno doméstico — IEC 60601-1 / IEC 60601-1-11

| ID | Componente | Requisito de diseño | Cómo verificar | Fase |
|---|---|---|---|---|
| RR-REQ-ENV-01 | Carcasa | Protección contra ingreso de agua. Mínimo normativo para entorno doméstico: IP21; IP22 si se porta durante el uso ⚠. Meta práctica, por sudor y limpieza con toallitas: sellar la unión de las dos piezas y el puerto | Prueba de goteo + inspección del sello | Piloto |
| RR-REQ-ENV-02 | Carcasa | Resiste caídas: equipo portátil, caída de 1 m sobre superficie dura, 3 veces ⚠ (cl. 15.3.4) | Prueba de caída + prueba funcional después | Piloto |
| RR-REQ-ENV-03 | Correa | La correa no se suelta durante los ejercicios; cierre que se pueda abrochar con una sola mano | Prueba con los 6 ejercicios del protocolo | Demo |
| RR-REQ-ENV-04 | Carcasa | La orientación de la colocación (flecha ▲ hacia el pulgar) es **visible y táctil**, y no se borra con la limpieza | Inspección tras 50 limpiezas | Piloto |

## 6. Biocompatibilidad — ISO 10993-1

Categoría probable: **dispositivo de superficie, piel intacta, contacto acumulado prolongado** (>24 h, ≤30 días) ⚠. Puntos finales típicos: citotoxicidad (ISO 10993-5), sensibilización (ISO 10993-10) e irritación (ISO 10993-23).

| ID | Componente | Requisito de diseño | Cómo verificar | Fase |
|---|---|---|---|---|
| RR-REQ-BIO-01 | Correa | Correa de un material con datos de biocompatibilidad (silicona grado médico o una correa comercial con declaración del fabricante) | Declaración o certificado del material | Piloto |
| RR-REQ-BIO-02 | Carcasa | El PETG impreso (con colorantes, aditivos y capas porosas) **no toca la piel directamente**, o se documenta su biocompatibilidad. Opción: ventana o tapa trasera de un material con datos | Lista de materiales en contacto con piel | Piloto |
| RR-REQ-BIO-03 | Correa | Hebilla o cierre sin níquel, o con liberación de níquel controlada (buena práctica, EN 1811) | Declaración del proveedor | Piloto |
| RR-REQ-BIO-04 | Documentación | Lista de materiales en contacto con piel: material, proveedor, lote y acabado | Archivo en el repo | Piloto |

## 7. Limpieza entre pacientes — ISO 17664-2 + IEC 60601-1 cl. 11.6.6

| ID | Componente | Requisito de diseño | Cómo verificar | Fase |
|---|---|---|---|---|
| RR-REQ-CLN-01 | Carcasa | Superficies lisas y sin grietas donde se acumule suciedad. En impresión 3D: lijado y sellado, o recubrimiento de la cara expuesta | Inspección visual con lupa | Piloto |
| RR-REQ-CLN-02 | Carcasa + etiqueta | Resiste N limpiezas con alcohol isopropílico al 70% y con toallitas de amonio cuaternario sin deformarse, agrietarse ni borrar las marcas. Proponer N = 200 ⚠ | Prueba de ciclos de limpieza | Piloto |
| RR-REQ-CLN-03 | Correa | Correa reemplazable por paciente, o limpiable con el mismo procedimiento | Procedimiento escrito | Piloto |
| RR-REQ-CLN-04 | Instructivo | Procedimiento de limpieza validado para la clínica: agente, tiempo de contacto y frecuencia | Documento + prueba | Producto |

## 8. Usabilidad — IEC 62366-1 + IEC 60601-1-6

| ID | Componente | Requisito de diseño | Cómo verificar | Fase |
|---|---|---|---|---|
| RR-REQ-USA-01 | Carcasa + correa | Una persona mayor se lo pone sola, con una mano, en < 60 s ⚠ (meta propia) | Evaluación formativa con 3–5 usuarios | Piloto |
| RR-REQ-USA-02 | LED | Los estados del LED se distinguen sin depender solo del color (parpadeo o patrón) | Revisión del firmware + prueba con usuarios | Piloto |
| RR-REQ-USA-03 | Carcasa | Botón (si existe) con fuerza y tamaño adecuados para dedos con poca destreza | Prueba con usuarios | Producto |
| RR-REQ-USA-04 | Documentación | Archivo de ingeniería de usabilidad: usuarios, tareas críticas y resultados de las evaluaciones formativas | Archivo en el repo | Piloto |

## 9. Marcado y etiquetado — NOM-137-SSA1-2025 + ISO 15223-1 + ISO 20417 + IEC 60601-1 cl. 7

> La **NOM-137-SSA1-2025** sustituye a la NOM-137-SSA1-2008. El documento de empaque del proyecto cita la 2008: hay que actualizarlo.

| ID | Componente | Requisito de diseño | Cómo verificar | Fase |
|---|---|---|---|---|
| RR-REQ-LAB-01 | Carcasa | Espacio para el marcado en el propio reloj: nombre, fabricante, modelo y **número de serie** (hoy RR-xxxx). Grabado o en relieve mejor que impreso | Revisión del CAD | Demo |
| RR-REQ-LAB-02 | Carcasa | El número de serie visible coincide con el ID BLE que muestra la app (relojes compartidos, emparejar el correcto) | Prueba con 2 relojes | Piloto |
| RR-REQ-LAB-03 | Etiqueta | Símbolos ISO 15223-1: fabricante, serie, "consulte las instrucciones", tipo de parte aplicada, código IP, eliminación de batería | Revisión de la etiqueta | Producto |
| RR-REQ-LAB-04 | Etiqueta | Durabilidad del marcado: prueba de frotado con agua y con alcohol (cl. 7.1.3) ⚠ | Prueba | Piloto |
| RR-REQ-LAB-05 | Etiqueta | Mientras no haya registro: leyenda **"Prototipo — uso exclusivo en investigación, no para venta"** | Revisión | Demo |

## 10. Gestión de riesgos — ISO 14971:2019

Peligros de hardware que deben quedar en la matriz de riesgos (hito R4), cada uno con un control y, cuando aplique, su ID de requisito:

| Peligro | Control (ID) |
|---|---|
| Sobrecalentamiento en piel | RR-REQ-TERM-01 |
| Falla de batería: fuga, hinchamiento, incendio | RR-REQ-BAT-01 a 05 |
| Choque eléctrico durante la carga | RR-REQ-ELEC-01, 04 |
| Irritación o alergia | RR-REQ-BIO-01 a 04 |
| Contaminación cruzada entre pacientes | RR-REQ-CLN-01 a 04 |
| Lesión por bordes o por desprendimiento durante el ejercicio | RR-REQ-MEC-01, ENV-03 |
| Piezas pequeñas o cable de carga al alcance de niños en casa | Instructivo + diseño sin piezas sueltas |
| Reloj emparejado con el paciente equivocado | RR-REQ-LAB-02 |
| Conteo erróneo que lleva a una decisión clínica equivocada | Validación T1/T4; verificado y reportado separados en el panel |
| Pérdida de datos de sesión | RR-REQ-EMC-03 |

## 11. Firmware y software (resumen)

| ID | Norma | Requisito |
|---|---|---|
| RR-REQ-SW-01 | IEC 62304 | Determinar la clase de seguridad del software (probable A o B ⚠); control de versiones y de cambios (`FW_VERSION`, `MODEL_VERSION`) |
| RR-REQ-SW-02 | IEC 81001-5-1 | BLE con emparejamiento y enlace seguros; el reloj no acepta comandos de dispositivos no vinculados |
| RR-REQ-SW-03 | IEC 62304 | Actualización de firmware controlada y registrada por unidad |
| RR-REQ-SW-04 | LFPDPPP 2025 | Los datos de salud viajan y se guardan protegidos; aviso de privacidad (hito R2) |

## 12. Fabricación y trazabilidad — NOM-241-SSA1-2025 + ISO 13485

| ID | Requisito | Dónde vive |
|---|---|---|
| RR-REQ-QMS-01 | **Expediente de diseño**: requisitos → diseño → verificación, trazables por ID. Este archivo es el inicio | Repo |
| RR-REQ-QMS-02 | **Registro por unidad**: serie, versión de firmware y modelo, lote de batería, material de carcasa y correa, pruebas de entrada y fecha | `devices/RR-xxxx.csv` o similar |
| RR-REQ-QMS-03 | Control de cambios del CAD: cada versión de carcasa con fecha y motivo (v1 → v2) | Repo |
| RR-REQ-VIG-01 | NOM-240-SSA1-2012 (tecnovigilancia): bitácora de incidentes durante el piloto | Repo + protocolo |

---

## 13. Mínimo para el Demo Day

- [ ] RR-REQ-BAT-03 — Cables de batería con alivio de tensión (relacionado con la falla de carga)
- [ ] RR-REQ-BAT-04 — Corte por bajo voltaje funcionando
- [ ] RR-REQ-ELEC-02 / 03 — Nada conductor en la cara de piel; USB-C en un lateral
- [ ] RR-REQ-MEC-01 — Sin bordes filosos
- [ ] RR-REQ-ENV-03 — La correa aguanta los 6 ejercicios
- [ ] RR-REQ-RF-02 — Alcance BLE correcto con el reloj puesto
- [ ] RR-REQ-LAB-01 / 05 — Número de serie visible y leyenda de prototipo
- [ ] Medición rápida de temperatura de la cara trasera tras 30 min (avance de RR-REQ-TERM-01)

## 14. Datos que faltan para cerrar la tabla

- Material y acabado exactos de la carcasa v2 y de la correa
- Hoja de datos y certificados de la celda LiPo actual
- Si la XIAO nRF52840 Sense tiene certificado IFT
- Posición de la antena en la placa respecto al CAD
- Duración real de las sesiones y frecuencia semanal del protocolo (para la categoría de biocompatibilidad)
