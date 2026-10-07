"use client";

import { Hand, Watch } from "lucide-react";
import useSWR from "swr";
import { Card, DataDisclaimer, ErrorBox, Spinner, Stat } from "@/components/ui";
import { fetcher } from "@/lib/api";
import { fmtPct } from "@/lib/format";
import type { Kpis } from "@/lib/types";

export default function ClinicPage() {
  const { data, error } = useSWR<Kpis>("/clinic/kpis", fetcher, { refreshInterval: 10_000 });
  if (error) return <ErrorBox error={error} />;
  if (!data) return <Spinner />;
  const d = data.devices;
  const fleet = d.available + d.assigned + d.cleaning;

  return (
    <div className="space-y-5">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Clínica</h1>
        <p className="text-sm text-muted">Resumen de los últimos 7 días.</p>
      </header>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card>
          <Stat label="Pacientes activos" value={data.activePatients} hint={`${data.patientsVerified} con reloj · ${data.patientsReported} sin reloj`} />
        </Card>
        <Card>
          <Stat label="Necesitan atención" value={data.patientsWithAlerts} tone={data.patientsWithAlerts ? "danger" : undefined} hint="Con al menos una alerta" />
        </Card>
        <Card>
          <Stat label="Relojes en uso" value={`${d.assigned} de ${fleet}`} hint={`${d.available} disponibles · ${d.cleaning} en limpieza`} />
        </Card>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <Card title={<span className="inline-flex items-center gap-1.5 text-verified"><Watch className="size-4" /> Verificado por el dispositivo</span>}>
          <div className="grid grid-cols-2 gap-4">
            <Stat label="Apego promedio" value={fmtPct(data.avgAdherence7.verified)} tone="verified" />
            <Stat label="Sesiones registradas" value={data.sessionsLast7.verified} />
          </div>
        </Card>
        <Card title={<span className="inline-flex items-center gap-1.5 text-reported"><Hand className="size-4" /> Reportado por el paciente</span>}>
          <div className="grid grid-cols-2 gap-4">
            <Stat label="Apego promedio" value={fmtPct(data.avgAdherence7.reported)} tone="reported" />
            <Stat label="Sesiones registradas" value={data.sessionsLast7.reported} />
          </div>
        </Card>
      </div>
      <p className="text-sm text-muted">
        Los dos orígenes se muestran por separado a propósito: lo reportado depende de la memoria y la honestidad del paciente; lo verificado lo cuenta el reloj.
      </p>
      <DataDisclaimer />
    </div>
  );
}
