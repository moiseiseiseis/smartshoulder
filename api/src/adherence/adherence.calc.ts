/**
 * Cálculo de apego (contexto/04 §5.3). Funciones puras: sin base de datos, para poder auditarlas y probarlas.
 *
 * - Sesión COMPLETA: todos los ejercicios prescritos con ≥ 90 % de las repeticiones.
 * - Apego (periodo) = sesiones completas ÷ sesiones esperadas (frecuencia semanal prorrateada a los días activos).
 * - Cumplimiento de volumen = Σ reps hechas ÷ Σ reps esperadas (reps por sesión × sesiones esperadas).
 * - Verificado y reportado se calculan SIEMPRE por separado; nunca se mezclan en el mismo indicador.
 */

export const COMPLETE_THRESHOLD = 0.9;
export const SKIPPED_THRESHOLD = 0.5; // un ejercicio con < 50 % de sus reps cuenta como "saltado"
export const ALERT_NO_SESSION_DAYS = 3;
export const ALERT_LOW_ADHERENCE_PCT = 50;
export const ALERT_ABORTED_IN_LAST = 3; // ≥ 2 abortadas entre las últimas 3 sesiones
export const ALERT_ABORTED_MIN = 2;

export type Source = 'VERIFIED' | 'REPORTED';
export type Status = 'COMPLETE' | 'INCOMPLETE' | 'ABORTED';

export interface ResultLite {
  exerciseId: number;
  repsDone: number;
  repsPrescribed: number;
}

export interface SessionLite {
  startedAt: Date;
  status: Status;
  source: Source;
  painScore?: number | null;
  effortScore?: number | null;
  results: ResultLite[];
}

export interface PrescriptionLite {
  frequencyPerWeek: number;
  startDate: Date;
  endDate?: Date | null;
  items: { exerciseId: number; sets: number; reps: number }[];
}

// ---------------------------------------------------------------- sesión

export function classifySession(results: ResultLite[], endedEarly: boolean): Status {
  const complete =
    results.length > 0 &&
    results.every((r) => r.repsPrescribed > 0 && r.repsDone / r.repsPrescribed >= COMPLETE_THRESHOLD);
  if (complete) return 'COMPLETE';
  return endedEarly ? 'ABORTED' : 'INCOMPLETE';
}

// ---------------------------------------------------------------- fechas (día local de la clínica)

export function dayKey(d: Date, tz: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: tz }).format(d); // YYYY-MM-DD
}

/** Lunes (YYYY-MM-DD) de la semana del día dado. */
export function weekKey(day: string): string {
  const d = new Date(`${day}T00:00:00Z`);
  const offset = (d.getUTCDay() + 6) % 7;
  d.setUTCDate(d.getUTCDate() - offset);
  return d.toISOString().slice(0, 10);
}

export function addDays(day: string, n: number): string {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000);
}

// ---------------------------------------------------------------- periodo

export function repsPerSession(p: PrescriptionLite): number {
  return p.items.reduce((s, i) => s + i.sets * i.reps, 0);
}

/** Días del rango [from, to] (inclusive) en que la prescripción estaba activa. */
export function activeDays(p: PrescriptionLite, from: string, to: string, tz: string): number {
  const start = maxDay(from, dayKey(p.startDate, tz));
  const end = p.endDate ? minDay(to, dayKey(p.endDate, tz)) : to;
  return Math.max(0, daysBetween(start, end) + 1);
}

export function expectedSessions(p: PrescriptionLite, days: number): number {
  if (days <= 0) return 0;
  return Math.max(1, Math.round((p.frequencyPerWeek * days) / 7));
}

export interface SourceMetrics {
  sessions: number;
  complete: number;
  expected: number;
  adherencePct: number | null; // null = sin sesiones de este origen en el periodo
  repsDone: number;
  repsExpected: number;
  volumePct: number | null;
}

export function sourceMetrics(
  sessions: SessionLite[],
  source: Source,
  p: PrescriptionLite,
  from: string,
  to: string,
  tz: string,
): SourceMetrics {
  const inRange = sessions.filter((s) => s.source === source && inDayRange(s.startedAt, from, to, tz));
  const expected = expectedSessions(p, activeDays(p, from, to, tz));
  const complete = inRange.filter((s) => s.status === 'COMPLETE').length;
  const repsDone = inRange.reduce((acc, s) => acc + s.results.reduce((a, r) => a + r.repsDone, 0), 0);
  const repsExpected = repsPerSession(p) * expected;
  const has = inRange.length > 0;
  return {
    sessions: inRange.length,
    complete,
    expected,
    adherencePct: has && expected ? pct(complete, expected) : null,
    repsDone,
    repsExpected,
    volumePct: has && repsExpected ? pct(repsDone, repsExpected) : null,
  };
}

// ---------------------------------------------------------------- alertas

export type Alert =
  | { type: 'NO_SESSION'; days: number }
  | { type: 'LOW_ADHERENCE'; pct: number }
  | { type: 'ABORTED_REPEATED'; count: number };

export function computeAlerts(
  sessions: SessionLite[],
  p: PrescriptionLite,
  primary: Source,
  today: string,
  tz: string,
): Alert[] {
  const alerts: Alert[] = [];
  const sorted = [...sessions].sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime());
  const lastDay = sorted.length ? dayKey(sorted[0].startedAt, tz) : maxDay(dayKey(p.startDate, tz), today);
  const idle = daysBetween(lastDay, today);
  if (idle >= ALERT_NO_SESSION_DAYS) alerts.push({ type: 'NO_SESSION', days: idle });

  const week = sourceMetrics(sessions, primary, p, addDays(today, -6), today, tz);
  const weekPct = week.adherencePct ?? 0;
  if (week.expected > 0 && activeDays(p, addDays(today, -6), today, tz) >= 3 && weekPct < ALERT_LOW_ADHERENCE_PCT) {
    alerts.push({ type: 'LOW_ADHERENCE', pct: weekPct });
  }

  const aborted = sorted.slice(0, ALERT_ABORTED_IN_LAST).filter((s) => s.status === 'ABORTED').length;
  if (aborted >= ALERT_ABORTED_MIN) alerts.push({ type: 'ABORTED_REPEATED', count: aborted });
  return alerts;
}

// ---------------------------------------------------------------- detalle

export type DayStatus = Status | 'NONE';

export function calendar(sessions: SessionLite[], from: string, to: string, tz: string) {
  const rank: Record<DayStatus, number> = { COMPLETE: 3, INCOMPLETE: 2, ABORTED: 1, NONE: 0 };
  const days: { day: string; status: DayStatus; source: Source | null }[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) {
    const ofDay = sessions.filter((s) => dayKey(s.startedAt, tz) === d);
    let best: SessionLite | null = null;
    for (const s of ofDay) if (!best || rank[s.status] > rank[best.status]) best = s;
    days.push({ day: d, status: best ? best.status : 'NONE', source: best ? best.source : null });
  }
  return days;
}

export function weekly(sessions: SessionLite[], p: PrescriptionLite, from: string, to: string, tz: string) {
  const out: { week: string; verified: SourceMetrics; reported: SourceMetrics }[] = [];
  for (let w = weekKey(from); w <= to; w = addDays(w, 7)) {
    const a = maxDay(w, from);
    const b = minDay(addDays(w, 6), to);
    out.push({
      week: w,
      verified: sourceMetrics(sessions, 'VERIFIED', p, a, b, tz),
      reported: sourceMetrics(sessions, 'REPORTED', p, a, b, tz),
    });
  }
  return out;
}

export function perExercise(sessions: SessionLite[], p: PrescriptionLite) {
  return p.items.map((item) => {
    const rs = sessions.flatMap((s) => s.results.filter((r) => r.exerciseId === item.exerciseId));
    const done = rs.reduce((a, r) => a + r.repsDone, 0);
    const prescribed = rs.reduce((a, r) => a + r.repsPrescribed, 0);
    const skipped = rs.filter((r) => r.repsPrescribed > 0 && r.repsDone / r.repsPrescribed < SKIPPED_THRESHOLD).length;
    return {
      exerciseId: item.exerciseId,
      repsDone: done,
      repsPrescribed: prescribed,
      completionPct: prescribed ? pct(done, prescribed) : null,
      skippedSessions: skipped,
      sessions: rs.length,
    };
  });
}

/** El ejercicio con menor cumplimiento (solo si está claramente por debajo del resto). */
export function mostSkipped(rows: ReturnType<typeof perExercise>): number | null {
  const valid = rows.filter((r) => r.completionPct !== null);
  if (valid.length < 2) return null;
  const worst = valid.reduce((a, b) => ((a.completionPct ?? 0) <= (b.completionPct ?? 0) ? a : b));
  return (worst.completionPct ?? 100) < 80 ? worst.exerciseId : null;
}

// ---------------------------------------------------------------- utilidades

function pct(a: number, b: number): number {
  return Math.min(100, Math.round((a / b) * 100));
}

function inDayRange(d: Date, from: string, to: string, tz: string): boolean {
  const k = dayKey(d, tz);
  return k >= from && k <= to;
}

function maxDay(a: string, b: string) {
  return a > b ? a : b;
}

function minDay(a: string, b: string) {
  return a < b ? a : b;
}
