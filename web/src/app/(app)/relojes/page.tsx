"use client";

import { Battery, Plus } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import useSWR from "swr";
import { Button, Card, DemoTag, ErrorBox, Spinner, cx, inputClass } from "@/components/ui";
import { fetcher, patch, post } from "@/lib/api";
import { deviceStatusLabel, relativeDay } from "@/lib/format";
import type { Device } from "@/lib/types";

const STATUS_TONE: Record<Device["status"], string> = {
  AVAILABLE: "bg-verified-soft text-verified",
  ASSIGNED: "bg-primary-soft text-primary",
  CLEANING: "bg-reported-soft text-reported",
  RETIRED: "bg-surface-2 text-muted",
};

export default function DevicesPage() {
  const { data, error, mutate } = useSWR<Device[]>("/devices", fetcher);
  const [name, setName] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<unknown>(null);

  async function act(key: string, fn: () => Promise<unknown>) {
    setBusy(key);
    setActionError(null);
    try {
      await fn();
      await mutate();
    } catch (e) {
      setActionError(e);
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="space-y-5">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Relojes</h1>
        <p className="text-sm text-muted">La flota de la clínica. Cada reloj se presta durante la rehabilitación en casa y regresa al alta.</p>
      </header>

      {error ? <ErrorBox error={error} /> : !data ? <Spinner /> : null}
      {actionError ? <ErrorBox error={actionError} /> : null}

      {data && (
        <div className="overflow-x-auto rounded-xl border border-border bg-surface">
          <table className="w-full min-w-[640px] text-sm">
            <thead className="bg-surface-2 text-left text-xs text-muted">
              <tr>
                <th className="px-4 py-2.5">Reloj</th>
                <th className="px-4 py-2.5">Estado</th>
                <th className="px-4 py-2.5">Paciente</th>
                <th className="px-4 py-2.5">Batería</th>
                <th className="px-4 py-2.5">Última sesión</th>
                <th className="px-4 py-2.5">Pacientes atendidos</th>
                <th className="px-4 py-2.5" />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {data.map((d) => (
                <tr key={d.id}>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2 font-mono font-semibold">
                      {d.bleName} {d.isDemo && <DemoTag />}
                    </div>
                    <div className="text-xs text-muted">
                      fw {d.fwVersion ?? "—"} · modelo {d.modelVersion ?? "—"}
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className={cx("rounded-full px-2 py-0.5 text-xs font-medium", STATUS_TONE[d.status])}>{deviceStatusLabel[d.status]}</span>
                  </td>
                  <td className="px-4 py-3">
                    {d.patient ? (
                      <Link href={`/pacientes/${d.patient.id}`} className="text-primary hover:underline">
                        {d.patient.displayName}
                      </Link>
                    ) : (
                      <span className="text-muted">—</span>
                    )}
                  </td>
                  <td className="tabular px-4 py-3">
                    {d.lastBattery == null ? (
                      <span className="text-muted">—</span>
                    ) : (
                      <span className={cx("inline-flex items-center gap-1", d.lastBattery < 20 && "text-danger")}>
                        <Battery className="size-4" /> {d.lastBattery}%
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-muted">{d.lastSeenAt ? relativeDay(d.lastSeenAt) : "—"}</td>
                  <td className="tabular px-4 py-3">{d.patientsServed}</td>
                  <td className="px-4 py-3 text-right">
                    {d.status === "ASSIGNED" && (
                      <Button variant="secondary" loading={busy === d.id} onClick={() => act(d.id, () => post(`/devices/${d.id}/return`))}>
                        Registrar devolución
                      </Button>
                    )}
                    {d.status === "CLEANING" && (
                      <Button variant="secondary" loading={busy === d.id} onClick={() => act(d.id, () => patch(`/devices/${d.id}/status`, { status: "AVAILABLE" }))}>
                        Limpio · disponible
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <Card title="Registrar reloj nuevo">
        <form
          className="flex flex-wrap gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            act("new", async () => {
              await post("/devices", { bleName: name });
              setName("");
            });
          }}
        >
          <input className={`${inputClass} max-w-48 font-mono uppercase`} placeholder="SS-XXXX" value={name} onChange={(e) => setName(e.target.value)} minLength={4} maxLength={16} required />
          <Button type="submit" loading={busy === "new"}>
            <Plus className="size-4" /> Agregar
          </Button>
          <p className="w-full text-xs text-muted">El nombre viene impreso en la carcasa (es el nombre Bluetooth del reloj).</p>
        </form>
      </Card>
    </div>
  );
}
