"use client";

import { Hand } from "lucide-react";
import { dayLabel, dayStatusLabel, weekdayLetter } from "@/lib/format";
import type { AdherenceDetail, DayStatus } from "@/lib/types";
import { cx } from "./ui";

const COLOR: Record<DayStatus, string> = {
  COMPLETE: "bg-[var(--day-complete)]",
  INCOMPLETE: "bg-[var(--day-incomplete)]",
  ABORTED: "bg-[var(--day-aborted)]",
  NONE: "bg-[var(--day-none)]",
};

/** Calendario por semanas (lunes a domingo). Los días reportados llevan el ícono de mano. */
export function AdherenceCalendar({ days, startDay }: { days: AdherenceDetail["calendar"]; startDay: string | null }) {
  if (!days.length) return null;
  const first = new Date(`${days[0].day}T12:00:00Z`);
  const pad = (first.getUTCDay() + 6) % 7; // empezar en lunes
  const cells: (AdherenceDetail["calendar"][number] | null)[] = [...Array(pad).fill(null), ...days];
  const weeks: typeof cells[] = [];
  for (let i = 0; i < cells.length; i += 7) weeks.push(cells.slice(i, i + 7));
  // No mostrar semanas completas anteriores al inicio del tratamiento.
  const visible = startDay ? weeks.filter((w) => w.some((c) => c && c.day >= startDay)) : weeks;

  return (
    <div>
      <div className="grid grid-cols-[52px_repeat(7,minmax(0,1fr))] gap-1 text-[11px] text-muted">
        <div />
        {["L", "M", "M", "J", "V", "S", "D"].map((d, i) => (
          <div key={i} className="text-center">
            {d}
          </div>
        ))}
        {visible.map((w, wi) => (
          <Week key={wi} cells={w} startDay={startDay} />
        ))}
      </div>
      <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted">
        {(["COMPLETE", "INCOMPLETE", "ABORTED", "NONE"] as DayStatus[]).map((s) => (
          <span key={s} className="inline-flex items-center gap-1.5">
            <span className={cx("size-3 rounded-sm", COLOR[s])} /> {dayStatusLabel[s]}
          </span>
        ))}
        <span className="inline-flex items-center gap-1.5">
          <Hand className="size-3" /> Reportado por el paciente
        </span>
        {startDay && (
          <span className="inline-flex items-center gap-1.5">
            <span className="size-3 rounded-sm border border-dashed border-muted" /> Antes del inicio ({dayLabel(startDay)})
          </span>
        )}
      </div>
    </div>
  );
}

function Week({ cells, startDay }: { cells: (AdherenceDetail["calendar"][number] | null)[]; startDay: string | null }) {
  const firstDay = cells.find(Boolean);
  return (
    <>
      <div className="self-center pr-1 text-right">{firstDay ? dayLabel(firstDay.day) : ""}</div>
      {Array.from({ length: 7 }, (_, i) => {
        const c = cells[i];
        if (!c) return <div key={i} />;
        if (startDay && c.day < startDay) {
          return <div key={c.day} title={`${dayLabel(c.day)}: antes del inicio del tratamiento`} className="aspect-square max-h-9 rounded-md border border-dashed border-border" />;
        }
        return (
          <div
            key={c.day}
            title={`${dayLabel(c.day)} (${weekdayLetter(c.day)}): ${dayStatusLabel[c.status]}${c.source === "REPORTED" ? " · reportado por el paciente" : c.source === "VERIFIED" ? " · verificado" : ""}`}
            className={cx("flex aspect-square max-h-9 items-center justify-center rounded-md", COLOR[c.status])}
          >
            {c.source === "REPORTED" && <Hand className="size-3 text-black/50" aria-label="reportado" />}
          </div>
        );
      })}
    </>
  );
}
