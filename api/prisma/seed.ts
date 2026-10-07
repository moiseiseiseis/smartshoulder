/**
 * Datos demo para desarrollo y Demo Day (contexto/04 §7: "claramente marcados como demo").
 * BORRA toda la base y la vuelve a llenar. Determinista: siempre genera la misma historia.
 *
 *   npx prisma db seed
 *
 * Accesos:  fisio@demo.mx / demo1234   ·   admin@demo.mx / demo1234   ·   app del paciente en vivo: código DEMO23
 */
import 'dotenv/config';
import { PrismaClient, SessionSource } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { addDays, classifySession, dayKey } from '../src/adherence/adherence.calc';

const prisma = new PrismaClient();
const TZ = process.env.TZ_CLINIC ?? 'America/Mexico_City';
const TODAY = dayKey(new Date(), TZ);

/** Hora local de CDMX (UTC−6, sin horario de verano desde 2022) → Date. */
const localTime = (day: string, hour: number, minute = 0) =>
  new Date(Date.parse(`${day}T00:00:00Z`) + ((hour + 6) * 60 + minute) * 60_000);

/** Generador pseudoaleatorio con semilla (mulberry32). */
function rng(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const EXERCISES = [
  { id: 0, name: 'NULO', instructions: 'No es un ejercicio: reposo, transiciones y actividades cotidianas.', sets: 0, reps: 0, enabled: false },
  { id: 1, name: 'Flexión anterior', instructions: 'De pie, brazo a un costado con la palma hacia el cuerpo. Eleva el brazo hacia el frente con el codo extendido hasta la altura indicada y baja controlado. Unos 2 s para subir y 2 s para bajar.', sets: 3, reps: 10 },
  { id: 2, name: 'Abducción', instructions: 'De pie, brazo a un costado. Eleva el brazo hacia el lado hasta la altura indicada y baja controlado. Unos 2 s para subir y 2 s para bajar.', sets: 3, reps: 10 },
  { id: 3, name: 'Rotación externa', instructions: 'Codo pegado al costado y doblado a 90°, banda anclada del lado contrario. Gira el antebrazo hacia afuera sin despegar el codo y regresa despacio.', sets: 3, reps: 12 },
  { id: 4, name: 'Rotación interna', instructions: 'Codo pegado al costado y doblado a 90°, banda anclada del mismo lado. Gira el antebrazo hacia el abdomen sin despegar el codo y regresa despacio.', sets: 3, reps: 12 },
  { id: 5, name: 'Extensión de tríceps', instructions: 'Banda anclada arriba (marco de puerta), codos pegados al cuerpo a 90°. Estira los codos hacia abajo y regresa a 90°.', sets: 3, reps: 12 },
  { id: 6, name: 'Estabilización escapular', instructions: 'Banda anclada al frente a la altura del pecho. Jala llevando los codos junto al cuerpo y juntando los omóplatos; sostén 1–2 s y regresa.', sets: 3, reps: 10 },
];

const TEMPLATES = [
  {
    key: 'manguito',
    name: 'Post-quirúrgico manguito rotador · fase intermedia',
    description: 'Semanas 3–6 tras reparación. Plantilla de demostración: validar con el fisioterapeuta colaborador.',
    weeks: 4,
    frequencyPerWeek: 5,
    items: [[1, 3, 10], [2, 3, 10], [3, 3, 12], [4, 3, 12]],
  },
  {
    key: 'tendinopatia',
    name: 'Tendinopatía del supraespinoso · fortalecimiento',
    description: 'Fortalecimiento progresivo con banda. Plantilla de demostración: validar con el fisioterapeuta colaborador.',
    weeks: 6,
    frequencyPerWeek: 4,
    items: [[3, 3, 12], [4, 3, 12], [5, 3, 12], [6, 3, 10]],
  },
] as const;

/**
 * Perfil de comportamiento de cada paciente demo:
 *  - attend(i, n, weekday): probabilidad de hacer sesión el día i (0 = inicio) de n días (weekday 0 = domingo).
 *  - reps(exerciseId, i, r, q): fracción de las repeticiones que completa (q = "calidad" de esa sesión, 0–1).
 */
interface Profile {
  name: string;
  diagnosis: string;
  arm: 'RIGHT' | 'LEFT';
  template: 'manguito' | 'tendinopatia';
  startDaysAgo: number;
  source: SessionSource;
  device?: string;
  attend: (i: number, n: number, weekday: number) => number;
  reps: (exerciseId: number, i: number, r: () => number, q: number) => number;
  aborts?: (i: number, n: number) => boolean;
  pain: (i: number, n: number) => number;
}

const full = () => 1;

const PROFILES: Profile[] = [
  {
    // Verificada: venía bien, lleva 4 días sin sesión y se salta la rotación externa.
    name: 'María González',
    diagnosis: 'Reparación de manguito rotador (supraespinoso)',
    arm: 'RIGHT',
    template: 'manguito',
    startDaysAgo: 20,
    source: 'VERIFIED',
    device: 'SS-D001',
    attend: (i, n) => (i >= n - 4 ? 0 : i < 10 ? 0.9 : 0.6),
    reps: (ex, i, _r, q) => (ex === 3 && i >= 5 && q < 0.85 ? 0.2 : 1),
    pain: (i) => Math.max(2, 6 - Math.floor(i / 5)),
  },
  {
    // Reportado: apego bajo, honesto.
    name: 'Juan Pérez',
    diagnosis: 'Tendinopatía del supraespinoso',
    arm: 'LEFT',
    template: 'tendinopatia',
    startDaysAgo: 35,
    source: 'REPORTED',
    attend: (i) => (i < 14 ? 0.6 : 0.3),
    reps: (_ex, _i, _r, q) => (q < 0.75 ? 1 : 0.6),
    pain: () => 4,
  },
  {
    // Verificada y constante.
    name: 'Ana López',
    diagnosis: 'Reparación de manguito rotador, post-quirúrgico',
    arm: 'LEFT',
    template: 'manguito',
    startDaysAgo: 12,
    source: 'VERIFIED',
    device: 'SS-D002',
    attend: () => 0.95,
    reps: full,
    pain: (i) => Math.max(1, 5 - Math.floor(i / 3)),
  },
  {
    // Reportado "perfecto": el contraste con lo verificado ("con Avena, todos son Roberto").
    name: 'Roberto Sánchez',
    diagnosis: 'Tendinopatía del supraespinoso',
    arm: 'RIGHT',
    template: 'tendinopatia',
    startDaysAgo: 28,
    source: 'REPORTED',
    attend: (_i, _n, weekday) => (weekday >= 1 && weekday <= 5 ? 1 : 0), // lunes a viernes: "perfecto"
    reps: () => 1,
    pain: () => 2,
  },
  {
    // Verificada: abandona sesiones a la mitad (dolor alto reportado).
    name: 'Carmen Ruiz',
    diagnosis: 'Hombro doloroso post-inmovilización',
    arm: 'RIGHT',
    template: 'manguito',
    startDaysAgo: 15,
    source: 'VERIFIED',
    device: 'SS-D003',
    attend: () => 0.7,
    reps: (_ex, i, r) => (i > 8 ? 0.2 + r() * 0.3 : 0.95),
    aborts: (i) => i > 8,
    pain: (i) => (i > 8 ? 7 : 5),
  },
];

async function reset() {
  if (process.env.NODE_ENV === 'production') throw new Error('El seed borra la base: no se corre en producción');
  await prisma.$transaction([
    prisma.sessionEvent.deleteMany(),
    prisma.sessionExerciseResult.deleteMany(),
    prisma.session.deleteMany(),
    prisma.prescriptionItem.deleteMany(),
    prisma.prescription.deleteMany(),
    prisma.deviceAssignment.deleteMany(),
    prisma.inviteCode.deleteMany(),
    prisma.patient.deleteMany(),
    prisma.device.deleteMany(),
    prisma.templateItem.deleteMany(),
    prisma.protocolTemplate.deleteMany(),
    prisma.auditLog.deleteMany(),
    prisma.user.deleteMany(),
    prisma.clinic.deleteMany(),
    prisma.exercise.deleteMany(),
  ]);
}

async function main() {
  await reset();

  await prisma.exercise.createMany({
    data: EXERCISES.map((e) => ({
      id: e.id,
      name: e.name,
      instructions: e.instructions,
      defaultSets: e.sets,
      defaultReps: e.reps,
      defaultRestSec: 45,
      enabled: e.enabled ?? true,
    })),
  });

  const clinic = await prisma.clinic.create({ data: { name: 'Clínica Demo de Fisioterapia' } });
  const passwordHash = await bcrypt.hash('demo1234', 10);
  const physio = await prisma.user.create({
    data: { clinicId: clinic.id, role: 'PHYSIO', name: 'Ft. Laura Méndez', email: 'fisio@demo.mx', passwordHash },
  });
  await prisma.user.create({
    data: { clinicId: clinic.id, role: 'CLINIC_ADMIN', name: 'Administración', email: 'admin@demo.mx', passwordHash },
  });

  const templates: Record<string, { id: string; frequencyPerWeek: number; items: readonly (readonly number[])[] }> = {};
  for (const t of TEMPLATES) {
    const created = await prisma.protocolTemplate.create({
      data: {
        name: t.name,
        description: t.description,
        weeks: t.weeks,
        frequencyPerWeek: t.frequencyPerWeek,
        items: { create: t.items.map(([exerciseId, sets, reps], order) => ({ exerciseId, sets, reps, restSec: 45, order })) },
      },
    });
    templates[t.key] = { id: created.id, frequencyPerWeek: t.frequencyPerWeek, items: t.items };
  }

  // Flota: el reloj real (SS-54F5) y relojes demo.
  const devices: Record<string, string> = {};
  for (const [bleName, isDemo] of [['SS-54F5', false], ['SS-D001', true], ['SS-D002', true], ['SS-D003', true], ['SS-D004', true], ['SS-D005', true]] as const) {
    const d = await prisma.device.create({ data: { clinicId: clinic.id, bleName, isDemo, fwVersion: 1, modelVersion: isDemo ? 1 : 0 } });
    devices[bleName] = d.id;
  }
  await prisma.device.update({ where: { id: devices['SS-D004'] }, data: { status: 'CLEANING' } });

  let seed = 42;
  for (const p of PROFILES) {
    const r = rng(seed++);
    const t = templates[p.template];
    const startDay = addDays(TODAY, -p.startDaysAgo);
    const patient = await prisma.patient.create({
      data: { clinicId: clinic.id, physioId: physio.id, displayName: p.name, diagnosis: p.diagnosis, affectedArm: p.arm, isDemo: true, createdAt: localTime(startDay, 10) },
    });
    const rx = await prisma.prescription.create({
      data: {
        patientId: patient.id,
        templateId: t.id,
        frequencyPerWeek: t.frequencyPerWeek,
        startDate: localTime(startDay, 10),
        createdById: physio.id,
        createdAt: localTime(startDay, 10),
        items: { create: t.items.map(([exerciseId, sets, reps], order) => ({ exerciseId, sets, reps, restSec: 45, order })) },
      },
    });
    if (p.device) {
      await prisma.deviceAssignment.create({ data: { deviceId: devices[p.device], patientId: patient.id, assignedAt: localTime(startDay, 10) } });
      await prisma.device.update({ where: { id: devices[p.device] }, data: { status: 'ASSIGNED', lastBattery: 40 + Math.floor(r() * 55) } });
    }

    const n = p.startDaysAgo; // hasta ayer: la única sesión de hoy es la de la demo en vivo
    for (let i = 0; i < n; i++) {
      const day = addDays(startDay, i);
      const weekday = new Date(`${day}T12:00:00Z`).getUTCDay();
      if (r() >= p.attend(i, p.startDaysAgo, weekday)) continue;
      const quality = r();
      const aborted = p.aborts?.(i, p.startDaysAgo) ?? false;
      const results = t.items.map(([exerciseId, sets, reps]) => {
        const frac = Math.min(1, p.reps(exerciseId, i, r, quality));
        const repsPrescribed = sets * reps;
        const repsDone = Math.round(repsPrescribed * frac);
        return { exerciseId, setsPrescribed: sets, repsPrescribed, repsDone, setsDone: Math.min(sets, Math.ceil(repsDone / reps)) };
      });
      const start = localTime(day, 17 + Math.floor(r() * 4), Math.floor(r() * 60));
      const minutes = aborted ? 6 + Math.floor(r() * 6) : 16 + Math.floor(r() * 10);
      await prisma.session.create({
        data: {
          clientSessionId: `seed-${patient.id}-${day}`,
          patientId: patient.id,
          prescriptionId: rx.id,
          source: p.source,
          deviceId: p.device ? devices[p.device] : null,
          fwVersion: p.device ? 1 : null,
          modelVersion: p.device ? 1 : null,
          startedAt: start,
          endedAt: new Date(start.getTime() + minutes * 60_000),
          status: classifySession(results, aborted),
          painScore: Math.min(10, Math.max(0, p.pain(i, p.startDaysAgo) + Math.round(r() * 2 - 1))),
          effortScore: 4 + Math.floor(r() * 4),
          isDemo: true,
          results: { create: results },
        },
      });
    }
    if (p.device) {
      const last = await prisma.session.findFirst({ where: { patientId: patient.id }, orderBy: { startedAt: 'desc' } });
      if (last) await prisma.device.update({ where: { id: devices[p.device] }, data: { lastSeenAt: last.endedAt } });
    }
  }

  // Paciente de la demo en vivo, con el reloj real.
  const live = await prisma.patient.create({
    data: { clinicId: clinic.id, physioId: physio.id, displayName: 'Paciente demo en vivo', diagnosis: 'Demostración (sujeto sano)', affectedArm: 'RIGHT', isDemo: true },
  });
  await prisma.prescription.create({
    data: {
      patientId: live.id,
      frequencyPerWeek: 5,
      startDate: localTime(TODAY, 8),
      createdById: physio.id,
      notes: 'Sesión corta para la demostración.',
      items: { create: [[1, 1, 5], [2, 1, 5]].map(([exerciseId, sets, reps], order) => ({ exerciseId, sets, reps, restSec: 20, order })) },
    },
  });
  await prisma.deviceAssignment.create({ data: { deviceId: devices['SS-54F5'], patientId: live.id } });
  await prisma.device.update({ where: { id: devices['SS-54F5'] }, data: { status: 'ASSIGNED' } });
  await prisma.inviteCode.create({ data: { code: 'DEMO23', patientId: live.id, expiresAt: new Date(Date.now() + 60 * 86_400_000) } });

  const counts = await prisma.session.groupBy({ by: ['source'], _count: true });
  console.log(`Seed listo (${TODAY}). Sesiones:`, counts.map((c) => `${c.source}=${c._count}`).join(' '));
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
