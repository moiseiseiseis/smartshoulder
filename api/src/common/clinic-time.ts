import { addDays, dayKey } from '../adherence/adherence.calc';

/** Zona horaria de la clínica: define qué es "hoy" y a qué día pertenece cada sesión. */
export const CLINIC_TZ = process.env.TZ_CLINIC ?? 'America/Mexico_City';

export const today = () => dayKey(new Date(), CLINIC_TZ);

/** Rango [from, to] validado; por defecto las últimas `days` jornadas. */
export function dayRange(from?: string, to?: string, days = 42): { from: string; to: string } {
  const re = /^\d{4}-\d{2}-\d{2}$/;
  const end = to && re.test(to) ? to : today();
  const start = from && re.test(from) ? from : addDays(end, -(days - 1));
  return { from: start, to: end };
}
