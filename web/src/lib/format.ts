import type { Alert, DayStatus, Device } from "./types";

const TZ = "America/Mexico_City";

export function relativeDay(iso: string | null): string {
  if (!iso) return "Nunca";
  const day = (d: Date) => new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(d);
  const diff = Math.round((Date.parse(day(new Date())) - Date.parse(day(new Date(iso)))) / 86_400_000);
  if (diff === 0) return `Hoy, ${time(iso)}`;
  if (diff === 1) return "Ayer";
  if (diff < 7) return `Hace ${diff} días`;
  return shortDate(iso);
}

export const time = (iso: string) =>
  new Intl.DateTimeFormat("es-MX", { timeZone: TZ, hour: "2-digit", minute: "2-digit" }).format(new Date(iso));

export const shortDate = (iso: string) =>
  new Intl.DateTimeFormat("es-MX", { timeZone: TZ, day: "numeric", month: "short" }).format(new Date(iso));

/** "2026-10-06" → "6 oct" (sin conversión de zona: ya es un día de la clínica). */
export const dayLabel = (day: string) =>
  new Intl.DateTimeFormat("es-MX", { timeZone: "UTC", day: "numeric", month: "short" }).format(new Date(`${day}T12:00:00Z`));

export const weekdayLetter = (day: string) =>
  new Intl.DateTimeFormat("es-MX", { timeZone: "UTC", weekday: "narrow" }).format(new Date(`${day}T12:00:00Z`));

export const armLabel = (arm: "RIGHT" | "LEFT") => (arm === "RIGHT" ? "Hombro derecho" : "Hombro izquierdo");

export function alertText(a: Alert): string {
  switch (a.type) {
    case "NO_SESSION":
      return `Sin sesión hace ${a.days} días`;
    case "LOW_ADHERENCE":
      return `Apego ${a.pct}% esta semana`;
    case "ABORTED_REPEATED":
      return `${a.count} sesiones abandonadas`;
  }
}

export const dayStatusLabel: Record<DayStatus, string> = {
  COMPLETE: "Completa",
  INCOMPLETE: "Incompleta",
  ABORTED: "Abandonada",
  NONE: "Sin sesión",
};

export const deviceStatusLabel: Record<Device["status"], string> = {
  AVAILABLE: "Disponible",
  ASSIGNED: "Prestado",
  CLEANING: "En limpieza",
  RETIRED: "Dado de baja",
};

export const fmtPct = (v: number | null | undefined) => (v === null || v === undefined ? "—" : `${v}%`);

export const duration = (sec: number) => `${Math.floor(sec / 60)} min`;
