import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import { AuthUser } from '../auth/auth.types';
import { CLINIC_TZ, today } from '../common/clinic-time';
import { PrismaService } from '../common/prisma.service';
import {
  addDays,
  calendar,
  computeAlerts,
  dayKey,
  mostSkipped,
  perExercise,
  PrescriptionLite,
  SessionLite,
  Source,
  sourceMetrics,
  weekly,
} from './adherence.calc';

/** Pacientes que el usuario puede ver: el fisio, los suyos; el admin, los de su clínica. */
export function patientScope(user: AuthUser): Prisma.PatientWhereInput {
  return user.role === Role.CLINIC_ADMIN
    ? { clinicId: user.clinicId }
    : { clinicId: user.clinicId, physioId: user.sub };
}

const patientInclude = {
  prescriptions: { where: { active: true }, include: { items: { orderBy: { order: 'asc' } } }, take: 1 },
  assignments: { where: { returnedAt: null }, include: { device: true }, take: 1 },
} satisfies Prisma.PatientInclude;

type PatientWithRx = Prisma.PatientGetPayload<{ include: typeof patientInclude }>;

const toLiteSession = (s: Prisma.SessionGetPayload<{ include: { results: true } }>): SessionLite => ({
  startedAt: s.startedAt,
  status: s.status,
  source: s.source,
  painScore: s.painScore,
  effortScore: s.effortScore,
  results: s.results,
});

@Injectable()
export class AdherenceService {
  constructor(private prisma: PrismaService) {}

  /** Origen principal del paciente: verificado si hoy tiene un reloj asignado. */
  primarySource(p: PatientWithRx): Source {
    return p.assignments.length ? 'VERIFIED' : 'REPORTED';
  }

  /** Filas de la lista de pacientes (pantalla de entrada del fisio). */
  async patientRows(user: AuthUser) {
    const patients = await this.prisma.patient.findMany({
      where: { ...patientScope(user), archivedAt: null },
      include: patientInclude,
    });
    const day = today();
    const since = new Date(Date.parse(`${addDays(day, -60)}T00:00:00Z`));
    const sessions = await this.prisma.session.findMany({
      where: { patientId: { in: patients.map((p) => p.id) }, startedAt: { gte: since } },
      include: { results: true },
    });

    const rows = patients.map((p) => {
      const rx = p.prescriptions[0];
      const own = sessions.filter((s) => s.patientId === p.id).map(toLiteSession);
      const primary = this.primarySource(p);
      const last = own.reduce<Date | null>((m, s) => (!m || s.startedAt > m ? s.startedAt : m), null);
      const base = {
        id: p.id,
        displayName: p.displayName,
        diagnosis: p.diagnosis,
        affectedArm: p.affectedArm,
        isDemo: p.isDemo,
        device: p.assignments[0]?.device.bleName ?? null,
        primarySource: primary,
        lastSessionAt: last,
      };
      if (!rx) return { ...base, week: null, adherence7: null, alerts: [] };
      const lite = this.toLitePrescription(rx);
      const m = sourceMetrics(own, primary, lite, addDays(day, -6), day, CLINIC_TZ);
      const startDay = dayKey(rx.startDate, CLINIC_TZ);
      const week = Math.floor((Date.parse(day) - Date.parse(startDay)) / (7 * 86_400_000)) + 1;
      return {
        ...base,
        week,
        adherence7: m.adherencePct ?? 0,
        alerts: computeAlerts(own, lite, primary, day, CLINIC_TZ),
      };
    });

    // Los que necesitan atención primero: más alertas y peor apego.
    return rows.sort((a, b) => b.alerts.length - a.alerts.length || (a.adherence7 ?? 101) - (b.adherence7 ?? 101));
  }

  /** Detalle de apego de un paciente en [from, to]. */
  async detail(user: AuthUser, patientId: string, from: string, to: string) {
    const p = await this.prisma.patient.findFirst({
      where: { id: patientId, ...patientScope(user) },
      include: patientInclude,
    });
    if (!p) throw new NotFoundException('Paciente no encontrado');
    const rx = p.prescriptions[0];
    const sessions = await this.prisma.session.findMany({
      where: {
        patientId,
        startedAt: { gte: new Date(Date.parse(`${addDays(from, -1)}T00:00:00Z`)), lte: new Date(Date.parse(`${addDays(to, 1)}T23:59:59Z`)) },
      },
      include: { results: true },
      orderBy: { startedAt: 'asc' },
    });
    const lite = sessions.map(toLiteSession).filter((s) => {
      const k = dayKey(s.startedAt, CLINIC_TZ);
      return k >= from && k <= to;
    });
    const empty = { from, to, startDay: null, calendar: calendar(lite, from, to, CLINIC_TZ), weekly: [], perExercise: [], mostSkipped: null };
    if (!rx) return { ...empty, last7: null, period: null, selfReports: [] };

    const rxLite = this.toLitePrescription(rx);
    const rows = perExercise(lite, rxLite);
    const day = today();
    const startDay = dayKey(rx.startDate, CLINIC_TZ);
    return {
      from,
      to,
      startDay, // los días previos no son "sin sesión": el tratamiento aún no empezaba
      calendar: empty.calendar,
      weekly: weekly(lite, rxLite, startDay > from ? startDay : from, to, CLINIC_TZ),
      perExercise: rows,
      mostSkipped: mostSkipped(rows),
      last7: {
        verified: sourceMetrics(lite, 'VERIFIED', rxLite, addDays(day, -6), day, CLINIC_TZ),
        reported: sourceMetrics(lite, 'REPORTED', rxLite, addDays(day, -6), day, CLINIC_TZ),
      },
      period: {
        verified: sourceMetrics(lite, 'VERIFIED', rxLite, from, to, CLINIC_TZ),
        reported: sourceMetrics(lite, 'REPORTED', rxLite, from, to, CLINIC_TZ),
      },
      // Dato del paciente, no medido por el dispositivo.
      selfReports: lite
        .filter((s) => s.painScore != null || s.effortScore != null)
        .map((s) => ({ day: dayKey(s.startedAt, CLINIC_TZ), pain: s.painScore, effort: s.effortScore })),
    };
  }

  /** Indicadores de la clínica (o del fisio). */
  async kpis(user: AuthUser) {
    const rows = await this.patientRows(user);
    const devices = await this.prisma.device.groupBy({
      by: ['status'],
      where: { clinicId: user.clinicId },
      _count: true,
    });
    const day = today();
    const weekStart = new Date(Date.parse(`${addDays(day, -6)}T00:00:00Z`));
    const sessions = await this.prisma.session.groupBy({
      by: ['source'],
      where: { patient: { ...patientScope(user), archivedAt: null }, startedAt: { gte: weekStart } },
      _count: true,
    });
    const avg = (source: Source) => {
      const r = rows.filter((x) => x.primarySource === source && x.adherence7 !== null);
      return r.length ? Math.round(r.reduce((a, x) => a + (x.adherence7 ?? 0), 0) / r.length) : null;
    };
    const count = (status: string) => devices.find((d) => d.status === status)?._count ?? 0;
    return {
      activePatients: rows.length,
      patientsVerified: rows.filter((r) => r.primarySource === 'VERIFIED').length,
      patientsReported: rows.filter((r) => r.primarySource === 'REPORTED').length,
      patientsWithAlerts: rows.filter((r) => r.alerts.length).length,
      avgAdherence7: { verified: avg('VERIFIED'), reported: avg('REPORTED') },
      sessionsLast7: {
        verified: sessions.find((s) => s.source === 'VERIFIED')?._count ?? 0,
        reported: sessions.find((s) => s.source === 'REPORTED')?._count ?? 0,
      },
      devices: {
        available: count('AVAILABLE'),
        assigned: count('ASSIGNED'),
        cleaning: count('CLEANING'),
        retired: count('RETIRED'),
      },
    };
  }

  toLitePrescription(rx: { frequencyPerWeek: number; startDate: Date; endDate: Date | null; items: { exerciseId: number; sets: number; reps: number }[] }): PrescriptionLite {
    return { frequencyPerWeek: rx.frequencyPerWeek, startDate: rx.startDate, endDate: rx.endDate, items: rx.items };
  }
}
