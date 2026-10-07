import {
  activeDays,
  calendar,
  classifySession,
  computeAlerts,
  dayKey,
  expectedSessions,
  mostSkipped,
  perExercise,
  PrescriptionLite,
  SessionLite,
  sourceMetrics,
  weekKey,
  weekly,
} from './adherence.calc';

const TZ = 'America/Mexico_City';
// 12:00 hora de CDMX = 18:00 UTC
const at = (day: string, hour = 12) => new Date(`${day}T${String(hour + 6).padStart(2, '0')}:00:00Z`);

const presc: PrescriptionLite = {
  frequencyPerWeek: 7,
  startDate: at('2026-09-07'), // lunes
  items: [
    { exerciseId: 1, sets: 3, reps: 10 },
    { exerciseId: 3, sets: 3, reps: 12 },
  ],
};

function session(day: string, source: 'VERIFIED' | 'REPORTED', reps: [number, number], ended = false): SessionLite {
  const results = [
    { exerciseId: 1, repsDone: reps[0], repsPrescribed: 30 },
    { exerciseId: 3, repsDone: reps[1], repsPrescribed: 36 },
  ];
  return { startedAt: at(day), source, status: classifySession(results, ended), results };
}

describe('classifySession', () => {
  it('completa solo si todos los ejercicios llegan al 90 %', () => {
    expect(classifySession([{ exerciseId: 1, repsDone: 27, repsPrescribed: 30 }], false)).toBe('COMPLETE');
    expect(classifySession([{ exerciseId: 1, repsDone: 26, repsPrescribed: 30 }], false)).toBe('INCOMPLETE');
  });
  it('abortada si se terminó antes y no llegó al umbral', () => {
    expect(classifySession([{ exerciseId: 1, repsDone: 5, repsPrescribed: 30 }], true)).toBe('ABORTED');
    expect(classifySession([{ exerciseId: 1, repsDone: 30, repsPrescribed: 30 }], true)).toBe('COMPLETE');
  });
  it('sin resultados nunca es completa', () => {
    expect(classifySession([], false)).toBe('INCOMPLETE');
  });
});

describe('fechas en la zona de la clínica', () => {
  it('una sesión a las 23:00 de CDMX cuenta en ese día, no en el siguiente (UTC)', () => {
    expect(dayKey(new Date('2026-09-08T05:00:00Z'), TZ)).toBe('2026-09-07');
  });
  it('la semana empieza en lunes', () => {
    expect(weekKey('2026-09-13')).toBe('2026-09-07'); // domingo → lunes anterior
    expect(weekKey('2026-09-07')).toBe('2026-09-07');
  });
});

describe('sesiones esperadas', () => {
  it('prorratea la frecuencia a los días activos', () => {
    expect(expectedSessions({ ...presc, frequencyPerWeek: 3 }, 7)).toBe(3);
    expect(expectedSessions({ ...presc, frequencyPerWeek: 3 }, 2)).toBe(1);
    expect(expectedSessions(presc, 0)).toBe(0);
  });
  it('no cuenta días antes del inicio de la prescripción', () => {
    expect(activeDays(presc, '2026-09-01', '2026-09-10', TZ)).toBe(4);
  });
});

describe('sourceMetrics', () => {
  const sessions = [
    session('2026-09-07', 'VERIFIED', [30, 36]),
    session('2026-09-08', 'VERIFIED', [30, 20]), // incompleta
    session('2026-09-09', 'REPORTED', [30, 36]),
  ];
  it('separa verificado y reportado', () => {
    const v = sourceMetrics(sessions, 'VERIFIED', presc, '2026-09-07', '2026-09-13', TZ);
    const r = sourceMetrics(sessions, 'REPORTED', presc, '2026-09-07', '2026-09-13', TZ);
    expect(v).toMatchObject({ sessions: 2, complete: 1, expected: 7, adherencePct: 14 });
    expect(v.repsDone).toBe(116);
    expect(r).toMatchObject({ sessions: 1, complete: 1, adherencePct: 14 });
  });
  it('null cuando no hay sesiones de ese origen (no es lo mismo que 0 %)', () => {
    const v = sourceMetrics([], 'VERIFIED', presc, '2026-09-07', '2026-09-13', TZ);
    expect(v.adherencePct).toBeNull();
    expect(v.volumePct).toBeNull();
  });
});

describe('alertas', () => {
  it('sin sesión en ≥ 3 días y apego bajo', () => {
    const s = [session('2026-09-07', 'VERIFIED', [30, 36])];
    const alerts = computeAlerts(s, presc, 'VERIFIED', '2026-09-11', TZ);
    expect(alerts).toEqual(
      expect.arrayContaining([
        { type: 'NO_SESSION', days: 4 },
        { type: 'LOW_ADHERENCE', pct: 20 },
      ]),
    );
  });
  it('abortadas repetidas', () => {
    const s = ['2026-09-08', '2026-09-09', '2026-09-10'].map((d, i) =>
      session(d, 'VERIFIED', i < 2 ? [3, 0] : [30, 36], i < 2),
    );
    expect(computeAlerts(s, presc, 'VERIFIED', '2026-09-10', TZ)).toContainEqual({
      type: 'ABORTED_REPEATED',
      count: 2,
    });
  });
  it('paciente al corriente no tiene alertas', () => {
    const days = ['2026-09-07', '2026-09-08', '2026-09-09', '2026-09-10', '2026-09-11'];
    const s = days.map((d) => session(d, 'VERIFIED', [30, 36]));
    expect(computeAlerts(s, presc, 'VERIFIED', '2026-09-11', TZ)).toEqual([]);
  });
  it('no alerta por apego bajo en los primeros días del tratamiento', () => {
    const p = { ...presc, startDate: at('2026-09-10') };
    expect(computeAlerts([], p, 'VERIFIED', '2026-09-11', TZ)).toEqual([]);
  });
});

describe('detalle', () => {
  const sessions = [
    session('2026-09-07', 'VERIFIED', [30, 10]),
    session('2026-09-07', 'VERIFIED', [30, 36], false), // dos el mismo día: gana la completa
    session('2026-09-09', 'VERIFIED', [30, 12]),
  ];
  it('calendario con el mejor estado del día', () => {
    const cal = calendar(sessions, '2026-09-07', '2026-09-09', TZ);
    expect(cal.map((d) => d.status)).toEqual(['COMPLETE', 'NONE', 'INCOMPLETE']);
  });
  it('series semanales', () => {
    const w = weekly(sessions, presc, '2026-09-07', '2026-09-20', TZ);
    expect(w.map((x) => x.week)).toEqual(['2026-09-07', '2026-09-14']);
    expect(w[0].verified.sessions).toBe(3);
  });
  it('detecta el ejercicio que más se salta', () => {
    const rows = perExercise(sessions, presc);
    expect(rows.find((r) => r.exerciseId === 3)?.skippedSessions).toBe(2);
    expect(mostSkipped(rows)).toBe(3);
  });
});
