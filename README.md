# SmartShoulder

Apego terapéutico en rehabilitación de hombro, **verificado por un reloj** (XIAO nRF52840 Sense + TinyML), con app para el paciente y dashboard para el fisioterapeuta.

| Carpeta | Qué es | Detalle |
|---|---|---|
| `contexto/` | Especificaciones (01–06), benchmark de Avena y plan (07) | |
| `contracts/ble.md` | Contrato Bluetooth entre reloj, app y herramienta de captura | Fuente de verdad |
| `firmware/` | Firmware de la XIAO (Arduino, core mbed de Seeed) | v1: modo captura |
| `tools/capture/` | Captura del dataset (Python) | [README](tools/capture/README.md) |
| `api/` | Backend NestJS + Prisma + PostgreSQL | [README](api/README.md) |
| `web/` | Dashboard del fisioterapeuta (Next.js) | |
| `app/` | App del paciente (Flutter) | [README](app/README.md) |

## Levantar todo en local

```
docker compose up -d                                   # PostgreSQL en localhost:5434
cd api && npm install && npx prisma migrate dev && npm run db:seed && npm run start:dev    # :3001
cd web && npm install && npm run dev                   # :3000
cd app && flutter run --dart-define=API_URL=http://<IP-de-la-PC>:3001
```

Accesos demo: `fisio@demo.mx` / `demo1234` (dashboard) · código `DEMO23` (app).

## Firmware

```
arduino-cli compile --fqbn Seeeduino:mbed:xiaonRF52840Sense --upload -p COM5 firmware/smartshoulder
```
Requiere el paquete de placas "Seeed nRF52 mbed-enabled Boards" y la librería ArduinoBLE.
