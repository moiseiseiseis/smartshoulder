# SmartShoulder API (NestJS + Prisma + PostgreSQL)

Backend compartido de la app del paciente y el dashboard del fisio (contexto/04 y 07).

## Arranque local

```
docker compose up -d          # desde la raíz del repo: PostgreSQL en localhost:5434
cd api
npm install
npx prisma migrate dev        # crea las tablas
npm run db:seed               # BORRA la base y carga los datos demo
npm run start:dev             # http://localhost:3001  ·  Swagger en /docs
```

Accesos demo: `fisio@demo.mx` / `demo1234` · `admin@demo.mx` / `demo1234` · app del paciente: código **DEMO23** (reloj SS-54F5).

El seed se basa en la fecha de hoy: vuelve a correrlo la mañana del Demo Day para que la historia quede al día.

## Pruebas

```
npm test                      # cálculo de apego (funciones puras)
node scripts/smoke.mjs        # recorrido completo contra la API corriendo (crea datos: luego vuelve a sembrar)
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `src/adherence/` | **Módulo regulado**: cálculo de apego (`adherence.calc.ts`), subida de sesiones, reportes, export CSV, KPIs |
| `src/management/` | Gestión: pacientes, prescripciones, invitaciones, flota de relojes, catálogo y plantillas |
| `src/auth/` | Login del fisio (correo y contraseña) y del paciente (código de invitación), roles |
| `src/common/` | Prisma, bitácora de auditoría, zona horaria de la clínica |

## Reglas

- Verificado y reportado se calculan por separado y nunca se mezclan en el mismo indicador.
- El backend decide si una sesión está completa (≥ 90 % de las repeticiones de cada ejercicio); la app solo manda lo que se hizo.
- La subida de sesiones es idempotente (`clientSessionId`), así que la app puede reintentar sin duplicar.
- Los días se cuentan en hora de la clínica (`TZ_CLINIC`, por defecto America/Mexico_City).
