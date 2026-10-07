"use client";

import { Bar, BarChart, CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { dayLabel } from "@/lib/format";
import type { AdherenceDetail } from "@/lib/types";

const AXIS = { fontSize: 11, fill: "var(--muted)" };

/** Repeticiones hechas contra esperadas por semana, separadas por origen. */
export function WeeklyRepsChart({ weekly }: { weekly: AdherenceDetail["weekly"] }) {
  const data = weekly.map((w) => ({
    week: dayLabel(w.week),
    esperadas: Math.max(w.verified.repsExpected, w.reported.repsExpected),
    verificadas: w.verified.repsDone,
    reportadas: w.reported.repsDone,
  }));
  const hasReported = data.some((d) => d.reportadas > 0);
  const hasVerified = data.some((d) => d.verificadas > 0);
  return (
    <ResponsiveContainer width="100%" height={220}>
      <BarChart data={data} barGap={2} margin={{ top: 4, right: 4, left: -12, bottom: 0 }}>
        <CartesianGrid vertical={false} stroke="var(--border)" />
        <XAxis dataKey="week" tick={AXIS} tickLine={false} axisLine={false} />
        <YAxis tick={AXIS} tickLine={false} axisLine={false} />
        <Tooltip cursor={{ fill: "var(--surface-2)" }} contentStyle={{ borderRadius: 8, fontSize: 12, borderColor: "var(--border)" }} />
        <Legend wrapperStyle={{ fontSize: 12 }} iconType="circle" iconSize={8} />
        <Bar dataKey="esperadas" name="Esperadas" fill="var(--day-none)" radius={[4, 4, 0, 0]} />
        {hasVerified && <Bar dataKey="verificadas" name="Hechas · verificadas" fill="var(--verified)" radius={[4, 4, 0, 0]} />}
        {hasReported && <Bar dataKey="reportadas" name="Hechas · reportadas" fill="var(--reported)" radius={[4, 4, 0, 0]} />}
      </BarChart>
    </ResponsiveContainer>
  );
}

/** Dolor y esfuerzo autorreportados (dato del paciente, no del sensor). */
export function SelfReportChart({ data }: { data: AdherenceDetail["selfReports"] }) {
  const rows = data.map((d) => ({ day: dayLabel(d.day), dolor: d.pain, esfuerzo: d.effort }));
  return (
    <ResponsiveContainer width="100%" height={180}>
      <LineChart data={rows} margin={{ top: 4, right: 8, left: -20, bottom: 0 }}>
        <CartesianGrid vertical={false} stroke="var(--border)" />
        <XAxis dataKey="day" tick={AXIS} tickLine={false} axisLine={false} minTickGap={24} />
        <YAxis domain={[0, 10]} ticks={[0, 5, 10]} tick={AXIS} tickLine={false} axisLine={false} />
        <Tooltip contentStyle={{ borderRadius: 8, fontSize: 12, borderColor: "var(--border)" }} />
        <Legend wrapperStyle={{ fontSize: 12 }} iconType="circle" iconSize={8} />
        <Line type="monotone" dataKey="dolor" name="Dolor (0–10)" stroke="var(--danger)" strokeWidth={2} dot={{ r: 2.5 }} />
        <Line type="monotone" dataKey="esfuerzo" name="Esfuerzo (0–10)" stroke="var(--primary)" strokeWidth={2} dot={{ r: 2.5 }} strokeDasharray="4 3" />
      </LineChart>
    </ResponsiveContainer>
  );
}
