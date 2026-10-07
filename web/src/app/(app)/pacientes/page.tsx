"use client";

import { ChevronRight, Plus } from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";
import useSWR from "swr";
import { AlertChip, cx, DemoTag, ErrorBox, PctBar, SourceBadge, Spinner } from "@/components/ui";
import { fetcher } from "@/lib/api";
import { relativeDay } from "@/lib/format";
import type { PatientRow } from "@/lib/types";

type Filter = "all" | "alerts" | "verified" | "reported";

export default function PatientsPage() {
  const { data, error, isLoading } = useSWR<PatientRow[]>("/patients", fetcher, { refreshInterval: 10_000 });
  const [filter, setFilter] = useState<Filter>("all");
  const [q, setQ] = useState("");

  const rows = useMemo(() => {
    let r = data ?? [];
    if (filter === "alerts") r = r.filter((p) => p.alerts.length);
    if (filter === "verified") r = r.filter((p) => p.primarySource === "VERIFIED");
    if (filter === "reported") r = r.filter((p) => p.primarySource === "REPORTED");
    if (q.trim()) r = r.filter((p) => p.displayName.toLowerCase().includes(q.trim().toLowerCase()));
    return r;
  }, [data, filter, q]);

  const count = (f: Filter) =>
    (data ?? []).filter((p) =>
      f === "alerts" ? p.alerts.length : f === "verified" ? p.primarySource === "VERIFIED" : f === "reported" ? p.primarySource === "REPORTED" : true,
    ).length;

  return (
    <div className="space-y-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Pacientes</h1>
          <p className="text-sm text-muted">Los que necesitan atención aparecen primero.</p>
        </div>
        <Link href="/pacientes/nuevo" className="inline-flex items-center gap-2 rounded-lg bg-primary px-3.5 py-2 text-sm font-medium text-white hover:bg-primary-hover">
          <Plus className="size-4" /> Nuevo paciente
        </Link>
      </header>

      <div className="flex flex-wrap items-center gap-2">
        {(
          [
            ["all", "Todos"],
            ["alerts", "Con alerta"],
            ["verified", "Con reloj"],
            ["reported", "Sin reloj"],
          ] as [Filter, string][]
        ).map(([f, label]) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={cx(
              "rounded-full border px-3 py-1 text-sm",
              filter === f ? "border-primary bg-primary-soft font-medium text-primary" : "border-border bg-surface text-muted hover:text-text",
            )}
          >
            {label} <span className="tabular">({count(f)})</span>
          </button>
        ))}
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Buscar por nombre"
          className="ml-auto w-full rounded-lg border border-border bg-surface px-3 py-1.5 text-sm outline-none focus:border-primary sm:w-56"
        />
      </div>

      {error ? <ErrorBox error={error} /> : isLoading ? <Spinner /> : null}

      {data && (
        <div className="overflow-hidden rounded-xl border border-border bg-surface">
          <table className="w-full text-sm">
            <thead className="hidden bg-surface-2 text-left text-xs font-medium text-muted md:table-header-group">
              <tr>
                <th className="px-4 py-2.5">Paciente</th>
                <th className="px-4 py-2.5">Semana</th>
                <th className="px-4 py-2.5">Apego 7 días</th>
                <th className="px-4 py-2.5">Última sesión</th>
                <th className="px-4 py-2.5">Atención</th>
                <th />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {rows.map((p) => (
                <tr key={p.id} className="group relative hover:bg-surface-2/60">
                  <td className="px-4 py-3">
                    <Link href={`/pacientes/${p.id}`} className="absolute inset-0" aria-label={`Ver ${p.displayName}`} />
                    <div className="flex items-center gap-2 font-medium">
                      {p.displayName} {p.isDemo && <DemoTag />}
                    </div>
                    <div className="text-xs text-muted">{p.diagnosis}</div>
                    <div className="mt-2 space-y-1.5 md:hidden">
                      <div className="flex flex-wrap items-center gap-2">
                        <PctBar value={p.adherence7} tone={p.primarySource === "VERIFIED" ? "verified" : "reported"} />
                        <SourceBadge source={p.primarySource} />
                      </div>
                      {p.alerts.length > 0 && (
                        <div className="flex flex-wrap gap-1">
                          {p.alerts.map((a) => (
                            <AlertChip key={a.type} alert={a} />
                          ))}
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="tabular hidden px-4 py-3 text-muted md:table-cell">{p.week ? `Sem ${p.week}` : "—"}</td>
                  <td className="hidden px-4 py-3 md:table-cell">
                    <div className="flex flex-col gap-1">
                      <PctBar value={p.adherence7} tone={p.primarySource === "VERIFIED" ? "verified" : "reported"} />
                      <div className="flex items-center gap-1.5">
                        <SourceBadge source={p.primarySource} />
                        {p.device && <span className="font-mono text-xs text-muted">{p.device}</span>}
                      </div>
                    </div>
                  </td>
                  <td className="hidden px-4 py-3 text-muted md:table-cell">{relativeDay(p.lastSessionAt)}</td>
                  <td className="hidden px-4 py-3 md:table-cell">
                    <div className="flex flex-wrap gap-1">
                      {p.alerts.length ? p.alerts.map((a) => <AlertChip key={a.type} alert={a} />) : <span className="text-xs text-muted">Al corriente</span>}
                    </div>
                  </td>
                  <td className="px-2 text-muted">
                    <ChevronRight className="size-4" />
                  </td>
                </tr>
              ))}
              {!rows.length && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-sm text-muted">
                    {data.length ? "Ningún paciente coincide con el filtro." : "Aún no hay pacientes. Da de alta al primero con “Nuevo paciente”."}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
      <p className="text-xs text-muted">
        El apego de cada paciente se mide con su origen principal: <b>verificado</b> si tiene un reloj prestado, <b>reportado</b> si marca sus sesiones a mano. Nunca se mezclan.
      </p>
    </div>
  );
}
