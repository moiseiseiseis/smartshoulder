# Rumbo Rehab — Identidad de marca

**Versión:** 1.0 (12 oct 2026)
**Estado:** dirección elegida: **B · Sendero**, logo 4 ("llegar con los brazos arriba").
**Uso:** fuente única de verdad para app del paciente (Flutter), dashboard del fisio (Next.js), backend/Swagger, presentación del Demo Day, documentos y carcasa del reloj.
**Relacionado:** `08-marca-rumbo-rehab.md` (qué se necesitaba y el renombre).

---

## 1. La idea

**Rumbo** cuenta la rehabilitación como un camino con dirección y destino. El isotipo lo dice en una sola imagen: **un sendero de pasos que llega a una persona con los brazos arriba**. Cada punto es una sesión; la meta es recuperar el movimiento del hombro.

- **Pasos (puntos índigo):** constancia, sesión por sesión. Es lo que mide el reloj.
- **Persona con los brazos arriba (girasol):** el paciente que llega. Flexión de hombro = rehabilitación lograda.
- **Tono:** profesional pero familiar. Un fisio lo ve como herramienta clínica seria; un paciente de 60 años lo siente cercano.

## 2. Logotipo

### 2.1 Versiones

| Versión | Composición | Uso |
|---|---|---|
| **Horizontal (principal)** | Isotipo a la izquierda + "rumbo" grande con "REHAB" espaciado debajo | Presentación, web, login, documentos |
| **Vertical** | Isotipo arriba, "rumbo" y "REHAB" centrados debajo | Splash de la app, portadas, espacios cuadrados |
| **Negativo** | Igual, sobre Índigo: sendero y "rumbo" en blanco, "REHAB" en `#D9D6F2`, figura en Girasol | Fondos de color, diapositivas oscuras |
| **Isotipo solo** | Sin texto | Ícono de app, favicon, carcasa, avatar en redes |
| **Monocromo** | Todo en un solo color (Tinta `#1E1B3A` o blanco) | Grabado, fax/impresión 1 tinta, sellos |

### 2.2 Construcción del logotipo

- **"rumbo":** Nunito 900, minúsculas, `letter-spacing: -0.02em`, `line-height: 0.9`, color Índigo.
- **"REHAB":** Nunito 800, mayúsculas, `letter-spacing: 0.42em`, tamaño ≈ **26%** del de "rumbo", color Pizarra `#55516E`.
- **Isotipo:** alto ≈ **1.45×** el tamaño de fuente de "rumbo"; separación isotipo–texto ≈ 0.25× ese tamaño.
- "Rumbo Rehab" se escribe así en texto corrido (con mayúsculas iniciales). El logotipo en minúsculas es solo el dibujo.

### 2.3 Área de protección y tamaños mínimos

- **Área libre** alrededor del logo: el diámetro de la cabeza de la figura × 2 por cada lado (≈ 20% del alto del isotipo).
- **Mínimos digitales:** isotipo 16 px (favicon), logotipo horizontal 120 px de ancho.
- **Mínimo en carcasa / impresión:** isotipo 10 mm.

### 2.4 Lo que no se hace

- No cambiar los colores fuera de las versiones de §2.1 ni poner la figura en otro color que no sea Girasol (o el monocromo).
- No rotar, estirar, añadir sombras, degradados ni contornos.
- No convertir la figura en cruz, corazón u otro símbolo (ya se exploró y se descartó).
- No poner el logo a color sobre fotos con fondo cargado; usar el negativo sobre una placa Índigo.
- No poner el Girasol pequeño sobre fondos claros sin revisar contraste (ver §3.3).

## 3. Color

### 3.1 Paleta

| Token | Nombre | Hex | Uso |
|---|---|---|---|
| `primary` | **Índigo** | `#3F3A9E` | Marca, botones principales, números grandes, enlaces |
| `primary-ink` | Índigo noche | `#2A2766` | Hover/pressed, ícono monocromo |
| `primary-soft` | Lavanda | `#E2E0F4` | Fondos suaves, chips, fondo del ícono monocromo |
| `on-primary-muted` | Lavanda clara | `#D9D6F2` | Texto secundario sobre Índigo ("REHAB" en negativo) |
| `accent` | **Girasol** | `#F2B33D` | La meta: figura del isotipo, día de hoy, progreso actual, destacados |
| `accent-deep` | Girasol profundo | `#B87C0C` | Girasol cuando va pequeño sobre fondo claro (ver §3.3) |
| `ink` | Tinta | `#1E1B3A` | Texto principal |
| `slate` | Pizarra | `#55516E` | Texto secundario |
| `mist` | Niebla | `#9A96AE` | Bordes fuertes, sendero punteado decorativo, deshabilitado. **No para texto** |
| `line` | Línea | `#E8E5F0` | Divisores, bordes de tarjeta |
| `canvas` | Crema | `#FAF8F4` | Fondo general |
| `surface` | Blanco | `#FFFFFF` | Tarjetas |

### 3.2 Colores semánticos (no cambian)

Siempre **ícono + color + texto**, nunca solo color.

| Token | Significado | Texto/ícono | Fondo suave | Ícono (Lucide) |
|---|---|---|---|---|
| `success` | **Verificado** por el reloj, sesión completa | `#0B7A62` | `#E3F3EE` | `circle-check` |
| `warning` | **Reportado** por el paciente, serie incompleta | `#915400` | `#FBF0DC` | `pencil` |
| `danger` | **Alerta**: sin sesión en días, batería baja, error | `#B42318` | `#FBE7E5` | `triangle-alert` |

Regla: el Girasol (marca) y el ámbar de "reportado" (estado) **no se mezclan**. Girasol = meta/hoy; ámbar = dato reportado.

### 3.3 Contraste verificado (WCAG)

| Combinación | Ratio | Veredicto |
|---|---|---|
| Índigo sobre blanco | 9.09 | ✅ AA texto |
| Índigo sobre Crema | 8.57 | ✅ AA texto |
| Tinta sobre Crema | 15.55 | ✅ AAA |
| Pizarra sobre Crema | 7.10 | ✅ AA texto (incluso pequeño) |
| Niebla sobre Crema | 2.69 | ❌ solo decorativo |
| Tinta sobre Girasol | 8.87 | ✅ texto sobre botones/etiquetas amarillas |
| Girasol sobre Índigo | 4.89 | ✅ figura en negativo e íconos |
| Lavanda clara sobre Índigo | 6.43 | ✅ |
| **Girasol sobre Crema** | **1.75** | ⚠️ no alcanza 3:1 para gráficos |
| Girasol profundo sobre Crema | 3.34 | ✅ gráficos (3:1) |
| Verificado sobre su fondo | 4.61 | ✅ |
| Reportado sobre su fondo | 5.36 | ✅ |
| Alerta sobre su fondo | 5.53 | ✅ |

**Regla práctica del Girasol:** a tamaño grande (logo ≥ 64 px, ilustración) el Girasol funciona sobre claro porque la figura se lee por forma. En tamaños pequeños sobre claro (favicon, ícono ≤ 32 px, impresión pequeña) usar **Girasol profundo**. Sobre Índigo, siempre Girasol normal. *Validar en pantalla y en impresión de prueba antes del Demo Day.*

## 4. Tipografía

**Una sola familia: Nunito** (Google Fonts, licencia SIL OFL; incluye acentos, ñ, ¿¡). Redondeada = cercana; pesos altos = firme.

| Rol | Peso | App paciente | Dashboard fisio |
|---|---|---|---|
| Contador de repeticiones | 900, `tabular-nums` | 96–104 px | — |
| Número KPI | 900, `tabular-nums` | 40 px | 32 px |
| Título de pantalla | 900 | 26 px / 1.2 | 24 px / 1.25 |
| Título de sección | 800 | 20 px / 1.3 | 18 px / 1.3 |
| Cuerpo | 400–600 | **18 px / 1.5** | 15 px / 1.5 |
| Etiqueta / chip | 700–800 | 15 px | 13 px |
| Pie / ayuda | 600 | 15 px (nunca menos) | 12 px |

- App del paciente: **mínimo 15 px** en cualquier texto; respetar el tamaño de fuente del sistema (no bloquear el escalado).
- Números siempre con cifras tabulares para que el contador no "baile".
- Mayúsculas espaciadas solo para "REHAB" y etiquetas muy cortas.

## 5. Espacio, forma y elevación

- **Espaciado (base 4):** 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64.
- **Radios:** `sm 8` (inputs pequeños) · `md 12` · `lg 20` (tarjetas) · `xl 28` (tarjeta del contador) · `pill 999` (botones y chips).
- **Elevación:** preferir borde `1px solid #E8E5F0` sobre sombras. Sombra única permitida para hojas/modales: `0 8px 24px rgba(30, 27, 58, 0.12)`.
- **Áreas táctiles:** ≥ 48 dp en la app (≥ 56 para el botón principal de sesión); ≥ 40 px en el dashboard.

## 6. El motivo del sendero

El sendero punteado es el recurso gráfico de la marca, no solo del logo:

- **"Su rumbo esta semana":** los 7 días unidos por una línea punteada (`border-top: 3px dotted #9A96AE`). Verificado = círculo verde con ✓; reportado = círculo ámbar con lápiz; hoy = círculo Girasol con anillo; pendiente = círculo blanco con borde Línea.
- **Metas del fisio:** cada meta es un "destino" al final de un sendero.
- **Progreso de series:** barras redondeadas: completadas en Índigo, actual en Girasol, pendientes en Línea.
- **Presentación:** el sendero puede cruzar diapositivas como hilo conductor (problema → solución → meta).
- No abusar: máximo un sendero por pantalla.

## 7. Iconografía

- **Familia:** [Lucide](https://lucide.dev) (licencia ISC, libre). Estilo de línea redondeada, coherente con Nunito.
- **Trazo:** 2 px a 24 px, puntas y uniones redondeadas. Tamaños: 16 · 20 · 24 · 32.
- **Color:** Índigo para acciones, Pizarra para íconos informativos, semánticos solo para estados.
- **Nunca emoji** en la interfaz.
- Paquetes: `lucide-react` en el dashboard; en Flutter, un paquete de Lucide de pub.dev (elegir el más mantenido al momento de instalar).

| Concepto | Ícono Lucide |
|---|---|
| Verificado | `circle-check` |
| Reportado | `pencil` |
| Alerta | `triangle-alert` |
| Reloj / dispositivo | `watch` |
| Bluetooth / conexión | `bluetooth` |
| Batería baja | `battery-low` |
| Sesión: iniciar / pausar | `play` / `pause` |
| Ejercicio | `activity` |
| Meta | `flag` |
| Calendario / semana | `calendar-days` |
| Recordatorio | `bell` |
| Paciente | `user-round` |
| Mensaje al fisio | `message-circle` |
| Ajustes | `settings` |
| Avanzar | `chevron-right` |

## 8. Recursos del isotipo (código)

> **Importante:** el sendero se dibuja con **círculos explícitos**, no con `stroke-dasharray`, porque `flutter_svg` y los VectorDrawable de Android no soportan líneas punteadas. Así se ve igual en todos lados.

### 8.1 Isotipo a color (fondos claros) — `rumbo-isotipo.svg`

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <g fill="#3F3A9E">
    <circle cx="8" cy="42" r="2.5"/>
    <circle cx="12.3" cy="35.2" r="2.5"/>
    <circle cx="20.3" cy="32.3" r="2.5"/>
    <circle cx="27.3" cy="27.8" r="2.5"/>
  </g>
  <path d="M27.5 10 Q36 28 44.5 10" fill="none" stroke="#F2B33D" stroke-width="4.5" stroke-linecap="round"/>
  <circle cx="36" cy="9" r="4.5" fill="#F2B33D"/>
</svg>
```

### 8.2 Isotipo en negativo (sobre Índigo) — `rumbo-isotipo-negativo.svg`

Igual que 8.1 cambiando `fill="#3F3A9E"` del grupo por `fill="#FFFFFF"`.

### 8.3 Isotipo monocromo — `rumbo-isotipo-mono.svg`

Igual que 8.1 con **todo** en un solo color (`#1E1B3A` o `#FFFFFF`). Es el archivo para grabar la carcasa.

### 8.4 Isotipo pequeño sobre claro — `rumbo-isotipo-sm.svg`

Igual que 8.1 cambiando los dos `#F2B33D` por `#B87C0C` (Girasol profundo). Para favicon y usos ≤ 32 px.

### 8.5 Logotipo horizontal (HTML/CSS)

```html
<div class="rr-logo">
  <img src="/brand/rumbo-isotipo.svg" alt="" width="72" height="72">
  <div class="rr-logo__text">
    <span class="rr-logo__name">rumbo</span>
    <span class="rr-logo__tag">REHAB</span>
  </div>
</div>
```

```css
.rr-logo { display: flex; align-items: center; gap: 12px; }
.rr-logo__text { display: flex; flex-direction: column; gap: 5px; }
.rr-logo__name { font: 900 50px/0.9 'Nunito', sans-serif; letter-spacing: -0.02em; color: var(--rr-primary); }
.rr-logo__tag  { font: 800 13px/1 'Nunito', sans-serif; letter-spacing: 0.42em; color: var(--rr-slate); }
```

Para usar el logotipo como imagen (presentación, PDF, impresión): armarlo una vez en Figma o Inkscape con Nunito y **convertir el texto a contornos**; exportar `rumbo-logo-horizontal.svg`, `-vertical.svg` y `-negativo.svg`.

## 9. Ícono de la app (Android)

Ícono adaptable: capa frontal (isotipo) + fondo (Índigo) + capa monocroma (Android 13+ la tiñe con el tema).

`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
```

`res/values/ic_launcher_background.xml`

```xml
<resources>
    <color name="ic_launcher_background">#3F3A9E</color>
</resources>
```

`res/drawable/ic_launcher_foreground.xml` (lienzo 108 dp; el isotipo ocupa ~54 dp centrado, dentro de la zona segura de 66 dp)

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <group android:translateX="19.80" android:translateY="21.93"
           android:scaleX="1.3091" android:scaleY="1.3091">
        <path android:fillColor="#FFFFFF"
            android:pathData="M5.5,42a2.5,2.5 0,1 0,5 0a2.5,2.5 0,1 0,-5 0
                              M9.8,35.2a2.5,2.5 0,1 0,5 0a2.5,2.5 0,1 0,-5 0
                              M17.8,32.3a2.5,2.5 0,1 0,5 0a2.5,2.5 0,1 0,-5 0
                              M24.8,27.8a2.5,2.5 0,1 0,5 0a2.5,2.5 0,1 0,-5 0"/>
        <path android:strokeColor="#F2B33D" android:strokeWidth="4.5"
            android:strokeLineCap="round" android:fillColor="#00000000"
            android:pathData="M27.5,10 Q36,28 44.5,10"/>
        <path android:fillColor="#F2B33D"
            android:pathData="M31.5,9a4.5,4.5 0,1 0,9 0a4.5,4.5 0,1 0,-9 0"/>
    </group>
</vector>
```

`res/drawable/ic_launcher_monochrome.xml`: el mismo archivo con los tres colores en `#FFFFFF` (Android usa solo la forma).

- **Nombre visible:** "Rumbo" (cabe completo bajo el ícono).
- **PNG de respaldo** (para versiones viejas y Play Store 512×512): exportar desde el SVG con fondo Índigo. Con `flutter_launcher_icons` se pueden generar todos los tamaños desde un PNG de 1024 px.
- **Splash:** fondo Crema, logotipo vertical centrado.
- **Favicon del dashboard:** `rumbo-isotipo-sm.svg` + `favicon.ico` 32 px con fondo Índigo y figura Girasol (versión negativa, se lee mejor en pestañas).

### 9.1 Paquete de archivos (`rumbo-rehab-marca.zip`)

Todos los textos del logotipo ya están **convertidos a contornos** (no dependen de tener Nunito instalada).

| Carpeta | Contenido | Para qué |
|---|---|---|
| `svg/` | `isotipo-{color, negativo, mono-tinta, mono-blanco, pequeno-claro}.svg` · `logo-{horizontal, vertical}-{color, negativo, mono-tinta, mono-blanco}.svg` · `logo-*-negativo-fondo-indigo.svg` | Web, presentación, impresión, carcasa (`isotipo-mono-tinta.svg`) |
| `png/` | Los mismos en PNG transparente: isotipos a 512 y 1024 px, logos horizontales a 2000 px de ancho, verticales a 1200 px | Canva, Slides, documentos, redes |
| `app-icon/` | `app-icon-1024.png` (para `flutter_launcher_icons`), `play-store-512.png`, capas adaptables `adaptive-foreground/monochrome/background-1024.png` + SVG | Ícono de la app |
| `android/res/` | `ic_launcher.xml`, `ic_launcher_foreground.xml`, `ic_launcher_monochrome.xml`, `ic_launcher_background.xml` | Copiar tal cual a `android/app/src/main/res/` |
| `web/` | `favicon.svg`, `favicon.ico` (16/32/48), `favicon-32.png`, `apple-touch-icon-180.png`, `icon-192.png`, `icon-512.png` | Dashboard Next.js (`app/` o `public/`) |

## 10. Tokens listos para usar

### 10.1 CSS (dashboard y web)

```css
:root {
  /* Marca */
  --rr-primary: #3F3A9E;
  --rr-primary-ink: #2A2766;
  --rr-primary-soft: #E2E0F4;
  --rr-on-primary: #FFFFFF;
  --rr-on-primary-muted: #D9D6F2;
  --rr-accent: #F2B33D;
  --rr-accent-deep: #B87C0C;
  --rr-on-accent: #1E1B3A;
  /* Neutros */
  --rr-ink: #1E1B3A;
  --rr-slate: #55516E;
  --rr-mist: #9A96AE;
  --rr-line: #E8E5F0;
  --rr-canvas: #FAF8F4;
  --rr-surface: #FFFFFF;
  /* Semánticos */
  --rr-success: #0B7A62;  --rr-success-soft: #E3F3EE;
  --rr-warning: #915400;  --rr-warning-soft: #FBF0DC;
  --rr-danger:  #B42318;  --rr-danger-soft:  #FBE7E5;
  /* Forma */
  --rr-radius-sm: 8px; --rr-radius-md: 12px; --rr-radius-lg: 20px;
  --rr-radius-xl: 28px; --rr-radius-pill: 999px;
  --rr-shadow-sheet: 0 8px 24px rgba(30, 27, 58, 0.12);
  /* Tipo */
  --rr-font: 'Nunito', system-ui, sans-serif;
}
```

### 10.2 Tailwind (`tailwind.config`)

```js
theme: {
  extend: {
    colors: {
      primary: { DEFAULT: '#3F3A9E', ink: '#2A2766', soft: '#E2E0F4' },
      accent:  { DEFAULT: '#F2B33D', deep: '#B87C0C' },
      ink: '#1E1B3A', slate: '#55516E', mist: '#9A96AE',
      line: '#E8E5F0', canvas: '#FAF8F4', surface: '#FFFFFF',
      success: { DEFAULT: '#0B7A62', soft: '#E3F3EE' },
      warning: { DEFAULT: '#915400', soft: '#FBF0DC' },
      danger:  { DEFAULT: '#B42318', soft: '#FBE7E5' },
    },
    fontFamily: { sans: ['Nunito', 'system-ui', 'sans-serif'] },
    borderRadius: { sm: '8px', md: '12px', lg: '20px', xl: '28px' },
  },
},
```

> Ojo: `slate` choca con la paleta por defecto de Tailwind; si molesta, renombrar a `rr-slate`.

### 10.3 Flutter (`lib/theme/rumbo_theme.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class RumboColors {
  static const primary = Color(0xFF3F3A9E);
  static const primaryInk = Color(0xFF2A2766);
  static const primarySoft = Color(0xFFE2E0F4);
  static const accent = Color(0xFFF2B33D);
  static const accentDeep = Color(0xFFB87C0C);
  static const ink = Color(0xFF1E1B3A);
  static const slate = Color(0xFF55516E);
  static const mist = Color(0xFF9A96AE);
  static const line = Color(0xFFE8E5F0);
  static const canvas = Color(0xFFFAF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const success = Color(0xFF0B7A62);
  static const successSoft = Color(0xFFE3F3EE);
  static const warning = Color(0xFF915400);
  static const warningSoft = Color(0xFFFBF0DC);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFBE7E5);
}

ThemeData rumboTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: RumboColors.primary).copyWith(
    primary: RumboColors.primary,
    onPrimary: Colors.white,
    primaryContainer: RumboColors.primarySoft,
    onPrimaryContainer: RumboColors.primaryInk,
    secondary: RumboColors.accent,
    onSecondary: RumboColors.ink,
    surface: RumboColors.surface,
    onSurface: RumboColors.ink,
    onSurfaceVariant: RumboColors.slate,
    outline: RumboColors.mist,
    outlineVariant: RumboColors.line,
    error: RumboColors.danger,
  );
  final text = GoogleFonts.nunitoTextTheme().apply(
    bodyColor: RumboColors.ink,
    displayColor: RumboColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RumboColors.canvas,
    textTheme: text.copyWith(
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 16, height: 1.5),
      titleLarge: text.titleLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w900),
      titleMedium: text.titleMedium?.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    cardTheme: CardTheme(
      color: RumboColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: RumboColors.line),
      ),
    ),
  );
}
```

> Para la demo sin internet, empaquetar Nunito en `assets/fonts/` en vez de descargarla con `google_fonts`. Contador: `TextStyle(fontWeight: FontWeight.w900, fontSize: 104, fontFeatures: [FontFeature.tabularFigures()])`.

### 10.4 JSON (fuente neutra, por si se generan los demás)

```json
{
  "color": {
    "primary": "#3F3A9E", "primary-ink": "#2A2766", "primary-soft": "#E2E0F4",
    "on-primary": "#FFFFFF", "on-primary-muted": "#D9D6F2",
    "accent": "#F2B33D", "accent-deep": "#B87C0C", "on-accent": "#1E1B3A",
    "ink": "#1E1B3A", "slate": "#55516E", "mist": "#9A96AE",
    "line": "#E8E5F0", "canvas": "#FAF8F4", "surface": "#FFFFFF",
    "success": "#0B7A62", "success-soft": "#E3F3EE",
    "warning": "#915400", "warning-soft": "#FBF0DC",
    "danger": "#B42318", "danger-soft": "#FBE7E5"
  },
  "radius": { "sm": 8, "md": 12, "lg": 20, "xl": 28, "pill": 999 },
  "space": [4, 8, 12, 16, 24, 32, 48, 64],
  "font": { "family": "Nunito", "weights": [400, 600, 700, 800, 900] }
}
```

## 11. Componentes base

| Componente | Estilo |
|---|---|
| **Botón principal** | Índigo, texto blanco 800, píldora, alto 56 (app) / 44 (dashboard) |
| **Botón secundario** | Fondo transparente, borde 2 px Índigo, texto Índigo |
| **Botón de celebración / CTA de marketing** | Girasol con texto Tinta. Usar poco: una vez por pantalla como máximo |
| **Tarjeta** | Blanco, borde Línea, radio 20, padding 20–24 |
| **Tarjeta del contador** | Blanco, radio 28, número Índigo 900 104 px, "de 12 repeticiones" en Pizarra |
| **Chip de estado** | Píldora, fondo suave semántico, ícono + texto 800 del color semántico |
| **Chip neutro** | Píldora, fondo Línea, texto Pizarra 700 ("Hombro derecho") |
| **Barra de series** | Segmentos de 10 px, radio 5: hechas Índigo, actual Girasol, pendientes Línea |
| **Gráficas (dashboard)** | Serie principal Índigo, comparación Girasol profundo, referencia Niebla punteada. Los semánticos solo para marcar estados, nunca como colores de serie |

## 12. Movimiento

- Transiciones de 200–300 ms, `ease-out`. Nada de rebotes exagerados.
- **Repetición contada:** el número cambia con un pequeño escalado (1.0 → 1.08 → 1.0, 180 ms) y una vibración ligera.
- **Sesión completa:** la figura del isotipo "sube los brazos" (el arco se dibuja de abajo hacia arriba, 600 ms) y el día de hoy se rellena en el sendero semanal.
- Respetar "reducir movimiento" del sistema: sin animación, solo cambio de estado.

## 13. Voz y tono

- **App del paciente: "usted".** Frases cortas, verbos claros, cero tecnicismos. *Validar en la prueba con usuarios (doc 09 §8).*
- **Dashboard del fisio: "tú".** Directo, de colega a colega, se permiten términos clínicos.
- Animar sin infantilizar: nada de "¡Súper!" ni signos de exclamación en cadena.
- Nunca culpar al paciente por no hacer la sesión.
- No prometer resultados clínicos; hablar de **constancia** y de **lo que el reloj verificó** (coherente con el uso previsto: verificar la ejecución del ejercicio prescrito, sin diagnóstico).

| Situación | Sí | No |
|---|---|---|
| Inicio de sesión | "Hoy le tocan 4 ejercicios. ¿Empezamos?" | "¡Hora de entrenar, campeón!" |
| Instrucción | "Mantenga el codo pegado al cuerpo." | "Realice rotación externa glenohumeral." |
| Sesión completa | "Sesión completa. Su fisioterapeuta ya puede verla." | "¡¡Increíble!! 🎉" |
| Días sin sesión | "No vemos sesiones desde el martes. Cuando pueda, retomamos." | "Llevas 3 días sin hacer tus ejercicios." |
| Reloj sin batería | "El reloj tiene poca batería. Póngalo a cargar antes de su sesión." | "Error: batería crítica." |
| Dashboard | "3 pacientes sin sesión esta semana" | "Pacientes incumplidos" |

## 14. Fotografía e ilustración

- **Fotografía real**, luz natural, en casa o en consultorio. Adultos de 40 a 70 años, diversidad real de Jalisco/México.
- Mostrar el reloj en la muñeca durante el ejercicio, con banda elástica, en contextos cotidianos.
- Evitar: fotos de stock de gimnasio, atletas de élite, gente sonriendo a la cámara sin hacer nada, imágenes de dolor o quirófano.
- Ilustración propia: pendiente para después del Demo Day (si se hace, línea redondeada en Índigo + acentos Girasol, mismo trazo que los íconos).

## 15. Aplicación por canal

| Canal | Qué lleva |
|---|---|
| **App Flutter** | `rumboTheme()`, ícono adaptable, splash Crema con logo vertical, "usted", contador Nunito 900 |
| **Dashboard Next.js** | Tokens CSS/Tailwind, favicon negativo, logo horizontal en la barra, "tú" |
| **Backend / Swagger** | Título "Rumbo Rehab API", color de cabecera Índigo |
| **Presentación Demo Day** | Fondo Crema o Índigo, logo horizontal en portada y cierre, sendero como hilo conductor, títulos Nunito 900 |
| **Carcasa del reloj** | Isotipo monocromo grabado (≥ 10 mm) junto a la flecha ▲ |
| **Relojes (BLE)** | Nombre `RR-XXXX` |
| **Documentos** | Encabezado con logo horizontal pequeño, cuerpo Nunito 400, títulos Índigo |

## 16. Pendientes

- [x] Logotipo con texto convertido a contornos (horizontal, vertical, negativo, monocromos) en SVG/PNG — ver §9.1.
- [ ] Validar el Girasol sobre fondo claro en pantalla y en una impresión de prueba (§3.3).
- [ ] Validar "usted" con pacientes en la prueba con usuarios.
- [ ] Verificación legal del nombre en IMPI (clases 9, 10 y 44), dominio y redes (doc 08 §5).
- [ ] Modo oscuro: no definido todavía (no es necesario para el Demo Day).
- [ ] Después del Demo Day: que un diseñador profesional pula el trazo del isotipo y el ajuste óptico del logotipo.
