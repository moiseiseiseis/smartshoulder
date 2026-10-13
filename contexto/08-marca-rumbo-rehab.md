# Rumbo Rehab — 08. Marca: qué se necesita y renombre del proyecto

**Versión:** 0.1 (12 oct 2026)
**Contexto:** el proyecto cambió de nombre: **SmartShoulder → Rumbo Rehab**. Todavía no hay marca. Este documento lista qué hace falta para el Demo Day (23 oct) y todo lo que toca el renombre.
**Relacionado:** `09-plan-upgrade-app.md` (la marca se aplica en la app), `10-guia-grabacion-videos.md`

---

## 1. La idea de marca

**"Rumbo" es la herramienta de diseño.** El nombre cuenta la rehabilitación como un camino con dirección y destino: cada sesión es un paso y el fisioterapeuta marca el rumbo. Esa metáfora es el hilo conductor de la app (sección "Tu rumbo", la semana como camino, metas como destinos) y del pitch.

Tono buscado: **profesional pero familiar**. Que un fisioterapeuta lo vea como herramienta clínica seria y que un paciente de 60 años lo sienta cercano, no intimidante.

## 2. Kit de marca mínimo para Demo Day

| # | Pieza | Qué es | Dónde se usa | Requisito clave |
|---|---|---|---|---|
| 1 | **Logotipo** | "Rumbo Rehab" escrito con tipografía propia o ajustada | Splash, login, dashboard, presentación, documentos | Legible en una línea y en dos ("Rumbo" / "Rehab") |
| 2 | **Isotipo** | Símbolo sin texto (brújula, ruta, hombro, flecha…) | Ícono de la app, favicon, grabado en la carcasa del reloj | Reconocible a 48 px y en un solo color |
| 3 | **Ícono de Android** | Isotipo sobre fondo, versión adaptable (capa frontal + fondo) y versión monocromática | Pantalla de inicio del celular (Android 13+ tiñe los íconos con el tema) | Que se lea dentro de un círculo y de un cuadrado redondeado |
| 4 | **Paleta** | 1 principal, 1 acento, 4–5 neutros y 3 semánticos | App, web, presentación | Contraste AA (4.5:1) en texto; los semánticos se distinguen también sin color |
| 5 | **Tipografía** | 1–2 familias de Google Fonts (licencia libre) | Todo | Números grandes muy legibles (el contador de la sesión), acentos y ñ completos |
| 6 | **Tono de voz** | Cómo habla la marca | Todos los textos de app, web y notificaciones | **Decidir "tú" o "usted"** (ver §4) |
| 7 | **Estilo visual** | Fotografía real o ilustración, estilo de íconos, cómo se mueven las animaciones | App y presentación | Coherente entre app y pitch |

### Colores semánticos que la marca debe respetar
Ya existen en la app y el dashboard; la paleta nueva los redefine pero conserva su significado:

| Significado | Uso | Hoy |
|---|---|---|
| **Logrado / verificado** | Sesión completa, apego verificado por el reloj | Verde `#0B7A62` |
| **Atención / reportado** | Apego reportado por el paciente, serie incompleta | Ámbar `#915400` |
| **Alerta** | Sin sesión en días, batería baja, errores | Rojo `#B42318` |

Regla que no cambia: **verificado y reportado siempre van con ícono + color + texto**, nunca solo color.

### Después del Demo Day (no ahora)
Manual de marca completo, papelería, empaque del reloj, ilustraciones propias, plantillas de redes sociales. Lo ideal es que un diseñador profesional pula la dirección elegida.

## 3. Cómo producirlo

1. Claude prepara **3 direcciones de marca** en una página (logo, isotipo, paleta, tipografía, ícono en un celular y la pantalla de sesión aplicada).
2. Moisés elige una (o mezcla) el mismo día.
3. Se aplica en app, web, presentación y carcasa.

Tiempo estimado: medio día de trabajo, más la decisión.

## 4. Decisiones pendientes

| Decisión | Opciones | Recomendación |
|---|---|---|
| **Tú o usted** en la app del paciente | "Tú": cercano, común en apps mexicanas. "Usted": respetuoso para pacientes de 60+ | **Usted** en la app del paciente, "tú" en el dashboard del fisio. Validar en la prueba con usuarios (doc 09 §8) |
| Dirección de marca | 3 propuestas | Elegir una el día 1 |

## 5. Verificación legal (antes de enamorarse del nombre)

- [ ] Buscar "Rumbo Rehab" y variantes en **IMPI** (marcanet.impi.gob.mx), en las clases **9** (software, aparatos de medición), **10** (aparatos médicos) y **44** (servicios de salud).
- [ ] Dominio disponible (`rumborehab.com` / `.mx`).
- [ ] Usuarios en redes sociales.
- [ ] Si todo está libre, considerar el registro de marca en cuanto haya presupuesto (es un trámite de varios meses).

## 6. Renombre: el nombre llega a todo

Decisión de Moisés: **el renombre es completo**, también en los identificadores internos. Se hace ahora porque, antes de tener usuarios, cuesta una hora; después cuesta mucho más.

| Componente | Qué cambia | Notas |
|---|---|---|
| **App Flutter** | Nombre visible, ícono, splash; identificador `mx.smartshoulder.smartshoulder` → `mx.rumborehab.app`; nombre del paquete Dart | Hay que **desinstalar la app vieja** del A36 una vez |
| **Reloj (firmware)** | Nombre Bluetooth `SS-XXXX` → **`RR-XXXX`**; textos de la consola | Reflashear la XIAO |
| **Contrato BLE** | `contracts/ble.md`: prefijo de nombre | Los UUID no cambian |
| **Herramienta de captura** | Prefijo de búsqueda `RR-`, títulos | |
| **Backend** | Textos, título de Swagger, datos demo (relojes `RR-…`) | Re-sembrar la base |
| **Base de datos local** | Nombre del contenedor y de la base (`rumborehab`) | Se recrea con `docker compose` |
| **Dashboard web** | Nombre, título de pestaña, favicon, colores | |
| **Paquete de ML** | `smartshoulder_ml` → `rumbo_ml` | |
| **Docs y READMEs** | Encabezados y referencias | Los docs 01–07 conservan su historia; se agrega una nota de renombre |
| **Repositorio** | Nombre en GitHub y carpeta local | **Lo hace Moisés:** GitHub → Settings → Rename (los enlaces viejos redirigen); la carpeta local con VS Code cerrado |
| **Carcasa del reloj** | Isotipo grabado en la tapa (junto a la flecha ▲) | Cuando exista el isotipo |
