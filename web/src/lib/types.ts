// Respuestas de la API (api/src). Mantener en sincronía con los servicios del backend.

export type Source = "VERIFIED" | "REPORTED";
export type SessionStatus = "COMPLETE" | "INCOMPLETE" | "ABORTED";
export type DayStatus = SessionStatus | "NONE";
export type Arm = "RIGHT" | "LEFT";

export type Alert =
  | { type: "NO_SESSION"; days: number }
  | { type: "LOW_ADHERENCE"; pct: number }
  | { type: "ABORTED_REPEATED"; count: number };

export interface PatientRow {
  id: string;
  displayName: string;
  diagnosis: string;
  affectedArm: Arm;
  isDemo: boolean;
  device: string | null;
  primarySource: Source;
  lastSessionAt: string | null;
  week: number | null;
  adherence7: number | null;
  alerts: Alert[];
}

export interface SourceMetrics {
  sessions: number;
  complete: number;
  expected: number;
  adherencePct: number | null;
  repsDone: number;
  repsExpected: number;
  volumePct: number | null;
}

export interface AdherenceDetail {
  from: string;
  to: string;
  startDay: string | null;
  calendar: { day: string; status: DayStatus; source: Source | null }[];
  weekly: { week: string; verified: SourceMetrics; reported: SourceMetrics }[];
  perExercise: {
    exerciseId: number;
    repsDone: number;
    repsPrescribed: number;
    completionPct: number | null;
    skippedSessions: number;
    sessions: number;
  }[];
  mostSkipped: number | null;
  last7: { verified: SourceMetrics; reported: SourceMetrics } | null;
  period: { verified: SourceMetrics; reported: SourceMetrics } | null;
  selfReports: { day: string; pain: number | null; effort: number | null }[];
}

export interface PrescriptionItem {
  id: string;
  exerciseId: number;
  sets: number;
  reps: number;
  restSec: number;
  order: number;
  exercise: { name: string };
}

export interface PatientDetail {
  id: string;
  displayName: string;
  affectedArm: Arm;
  diagnosis: string;
  isDemo: boolean;
  physio: string;
  createdAt: string;
  archivedAt: string | null;
  appLinked: boolean;
  device: { id: string; bleName: string; lastBattery: number | null; lastSeenAt: string | null; modelVersion: number | null } | null;
  invite: { code: string; expiresAt: string; usedAt: string | null; qr: string } | null;
  prescription: {
    id: string;
    frequencyPerWeek: number;
    startDate: string;
    notes: string | null;
    template: { name: string } | null;
    items: PrescriptionItem[];
  } | null;
  prescriptionHistory: {
    id: string;
    createdAt: string;
    createdBy: string;
    template: string | null;
    frequencyPerWeek: number;
    items: string[];
    active: boolean;
  }[];
}

export interface SessionView {
  id: string;
  day: string;
  startedAt: string;
  durationSec: number;
  status: SessionStatus;
  source: Source;
  painScore: number | null;
  effortScore: number | null;
  device: string | null;
  modelVersion: number | null;
  results: { exerciseId: number; name: string; repsDone: number; repsPrescribed: number; setsDone: number; setsPrescribed: number }[];
}

export interface Exercise {
  id: number;
  name: string;
  instructions: string;
  defaultSets: number;
  defaultReps: number;
  defaultRestSec: number;
}

export interface Template {
  id: string;
  name: string;
  description: string;
  weeks: number | null;
  frequencyPerWeek: number;
  items: { exerciseId: number; sets: number; reps: number; restSec: number; exercise: { name: string } }[];
}

export interface Device {
  id: string;
  bleName: string;
  status: "AVAILABLE" | "ASSIGNED" | "CLEANING" | "RETIRED";
  isDemo: boolean;
  lastBattery: number | null;
  lastSeenAt: string | null;
  fwVersion: number | null;
  modelVersion: number | null;
  patient: { id: string; displayName: string } | null;
  patientsServed: number;
}

export interface Kpis {
  activePatients: number;
  patientsVerified: number;
  patientsReported: number;
  patientsWithAlerts: number;
  avgAdherence7: { verified: number | null; reported: number | null };
  sessionsLast7: { verified: number; reported: number };
  devices: { available: number; assigned: number; cleaning: number; retired: number };
}
