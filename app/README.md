# SmartShoulder — app del paciente (Flutter)

Guía la sesión de ejercicios en casa, se conecta al reloj por Bluetooth LE y envía la sesión al backend (contexto/01).

## Correr

```
flutter pub get
flutter run --dart-define=API_URL=http://<IP-de-la-PC>:3001     # celular real en la misma red
flutter run                                                        # emulador Android: usa http://10.0.2.2:3001
flutter build apk --debug                                          # build/app/outputs/flutter-apk/app-debug.apk
```

El servidor también se puede cambiar en **Ajustes** (desde la bienvenida: "Ajustes de conexión").

Para probar: código **DEMO23** (paciente demo en vivo, reloj SS-54F5).

## Reloj simulado (plan B de la demo)

Ajustes → toca 5 veces el título **"Ajustes"** → activa **"Reloj simulado (demostración)"**.
Genera una repetición cada ~3 s del ejercicio esperado. Úsalo si el Bluetooth falla en el escenario o para desarrollar sin hardware.

> El firmware v1 todavía no manda repeticiones (no tiene el modelo). Hasta el firmware v2, las sesiones verificadas solo cuentan con el simulador.

## Estructura

| Carpeta | Contenido |
|---|---|
| `lib/core/contract.dart` | Espejo de `contracts/ble.md` (UUIDs, comandos, `EVENTS`, `STATUS`) |
| `lib/core/device/` | `DeviceClient`: `BleDevice` (flutter_reactive_ble, BSD-3) y `SimulatedDevice` |
| `lib/core/sync.dart` | Cola offline: la sesión se guarda en el teléfono y se sube con reintentos; `clientSessionId` evita duplicados |
| `lib/features/session/session_engine.dart` | Flujo de la sesión en Dart puro (series, descansos, reps verificadas o reportadas), con pruebas |
| `lib/features/…` | Pantallas: bienvenida/QR, privacidad, emparejamiento, inicio, sesión, resumen, historial, ajustes |

## Decisiones

- **flutter_reactive_ble** en lugar de flutter_blue_plus: la 2.x de flutter_blue_plus exige licencia de pago para uso comercial y envía telemetría al compilar.
- `minSdk 24` (Android 7.0), por flutter_tts. AGP 8.7.3, Kotlin 2.1, Gradle 8.10.2 (los pide mobile_scanner).
- `permission_handler` fijado en 11.4.0: la 13 requiere un Kotlin Gradle Plugin más nuevo que el de Flutter 3.27.

## Pruebas

```
flutter test        # motor de sesión y contrato BLE
flutter analyze
```
