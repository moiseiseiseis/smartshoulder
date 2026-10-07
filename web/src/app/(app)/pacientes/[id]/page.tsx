"use client";

import { ArrowLeft, Battery, Download, Pencil, RefreshCw, Smartphone, TrendingDown, Watch } from "lucide-react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { QRCodeSVG } from "qrcode.react";
import { useState } from "react";
import useSWR from "swr";
import { AdherenceCalendar } from "@/components/AdherenceCalendar";
import { SelfReportChart, WeeklyRepsChart } from "@/components/Charts";
import { PrescriptionEditor, draftToBody, type RxDraft } from "@/components/PrescriptionEditor";
import { Button, Card, DataDisclaimer, DemoTag, ErrorBox, PctBar, SourceBadge, Spinner, Stat, cx, inputClass } from "@/components/ui";
import { download, fetcher, post } from "@/lib/api";
import { armLabel, dayStatusLabel, duration, fmtPct, relativeDay, shortDate } from "@/lib/format";
import type { AdherenceDetail, Device, PatientDetail, SessionView, Source, SourceMetrics } from "@/lib/types";

const LIVE = { refreshInterval: 5_000 }; // la demo en vivo se ve aparecer sin recargar

export default function PatientDetailPage() {
  const { id } = useParams<{ id: string }>();
  const patient = useSWR<PatientDetail>(`/patients/${id}`, fetcher, LIVE);
  const adherence = useSWR<AdherenceDetail>(`/patients/${id}/adherence`, fetcher, LIVE);
  const sessions = useSWR<SessionView[]>(`/patients/${id}/sessions`, fetcher, LIVE);

  if (patient.error) return <ErrorBox error={patient.error} />;
  if (!patient.data || !adherence.data) return <Spinner />;
  const p = patient.data;
  const a = adherence.data;
  const primary: Source = p.device ? "VERIFIED" : "REPORTED";
  const names = Object.fromEntries((p.prescription?.items ?? []).map((i) => [i.exerciseId, i.exercise.name]));
  const reload = () => Promise.all([patient.mutate(), adherence.mutate(), sessions.mutate()]);

  return (
    <div className="space-y-5">
      <Link href="/pacientes" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <ArrowLeft className="size-4" /> Pacientes
      </Link>

      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-semibold tracking-tight">{p.displayName}</h1>
            {p.isDemo && <DemoTag />}
          </div>
          <p className="text-sm text-muted">
            {p.diagnosis} · {armLabel(p.affectedArm)} · {p.physio}
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="secondary" onClick={() => download(`/patients/${id}/export.csv`, `apego-${p.displayName.replace(/\s+/g, "_")}.csv`)}>
            <Download className="size-4" /> Exportar CSV
          </Button>
        </div>
      </header>

      <SummaryStrip a={a} primary={primary} lastSession={sessions.data?.[0]?.startedAt ?? null} />

      <div className="grid gap-5 lg:grid-cols-[1fr_320px]">
        <div className="min-w-0 space-y-5">
          <Card title="Calendario de apego">
            <AdherenceCalendar days={a.calendar} startDay={a.startDay} />
          </Card>

          <Card title="Repeticiones por semana">
            <WeeklyRepsChart weekly={a.weekly} />
          </Card>

          <Card title="Por ejercicio">
            <ExerciseTable a={a} names={names} />
          </Card>

          {a.selfReports.length > 0 && (
            <Card title="Dolor y esfuerzo" action={<SourceBadge source="REPORTED" long />}>
              <SelfReportChart data={a.selfReports} />
            </Card>
          )}

          <Card title="Sesiones">
            <SessionList sessions={sessions.data} />
          </Card>
          <DataDisclaimer />
        </div>

        <aside className="space-y-5">
          <DeviceCard p={p} onChange={reload} />
          <AppCard p={p} onChange={reload} />
          <PrescriptionCard p={p} onChange={reload} />
          <DischargeButton id={p.id} />
        </aside>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- resumen

function SummaryStrip({ a, primary, lastSession }: { a: AdherenceDetail; primary: Source; lastSession: string | null }) {
  if (!a.last7) return null;
  const sources: Source[] = (["VERIFIED", "REPORTED"] as Source[]).filter((s) => s === primary || metrics(a.last7!, s).sessions > 0);
  const pain = a.selfReports.at(-1)?.pain;
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      {sources.map((s) => {
        const m = metrics(a.last7!, s);
        return (
          <div key={s} className="rounded-xl border border-border bg-surface p-4">
            <div className="mb-2">
              <SourceBadge source={s} long />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <Stat label="Apego 7 días" value={fmtPct(m.adherencePct ?? 0)} tone={(m.adherencePct ?? 0) < 50 ? "danger" : undefined} hint={`${m.complete} de ${m.expected} sesiones`} />
              <Stat label="Volumen" value={fmtPct(m.volumePct ?? 0)} hint={`${m.repsDone} de ${m.repsExpected} reps`} />
            </div>
          </div>
        );
      })}
      <div className="rounded-xl border border-border bg-surface p-4">
        <Stat label="Última sesión" value={<span className="text-lg">{relativeDay(lastSession)}</span>} />
      </div>
      <div className="rounded-xl border border-border bg-surface p-4">
        <Stat label="Último dolor reportado" value={pain == null ? "—" : `${pain}/10`} hint="Reportado por el paciente" />
      </div>
    </div>
  );
}

const metrics = (x: { verified: SourceMetrics; reported: SourceMetrics }, s: Source) => (s === "VERIFIED" ? x.verified : x.reported);

function ExerciseTable({ a, names }: { a: AdherenceDetail; names: Record<number, string> }) {
  if (!a.perExercise.length) return <p className="text-sm text-muted">Sin prescripción activa.</p>;
  return (
    <table className="w-full text-sm">
      <thead className="text-left text-xs text-muted">
        <tr>
          <th className="pb-2">Ejercicio</th>
          <th className="pb-2">Repeticiones cumplidas</th>
          <th className="hidden pb-2 sm:table-cell">Sesiones con &lt; 50 %</th>
        </tr>
      </thead>
      <tbody className="divide-y divide-border">
        {a.perExercise.map((r) => (
          <tr key={r.exerciseId} className={cx(a.mostSkipped === r.exerciseId && "bg-danger-soft/50")}>
            <td className="py-2.5 pr-3">
              <div className="font-medium">{names[r.exerciseId] ?? `Ejercicio ${r.exerciseId}`}</div>
              {a.mostSkipped === r.exerciseId && (
                <div className="mt-0.5 inline-flex items-center gap-1 text-xs font-medium text-danger">
                  <TrendingDown className="size-3.5" /> El que más se salta
                </div>
              )}
            </td>
            <td className="py-2.5 pr-3">
              <PctBar value={r.completionPct} />
              <div className="tabular text-xs text-muted">
                {r.repsDone} de {r.repsPrescribed}
              </div>
            </td>
            <td className="tabular hidden py-2.5 sm:table-cell">
              {r.skippedSessions} de {r.sessions}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function SessionList({ sessions }: { sessions?: SessionView[] }) {
  if (!sessions) return <Spinner />;
  if (!sessions.length) return <p className="text-sm text-muted">Todavía no hay sesiones.</p>;
  const tone = { COMPLETE: "text-ok", INCOMPLETE: "text-reported", ABORTED: "text-danger" } as const;
  return (
    <ul className="divide-y divide-border">
      {sessions.slice(0, 12).map((s) => (
        <li key={s.id} className="flex flex-wrap items-center gap-x-4 gap-y-1 py-2.5 text-sm">
          <div className="w-32 shrink-0">
            <div className="font-medium">{relativeDay(s.startedAt)}</div>
            <div className="text-xs text-muted">{duration(s.durationSec)}</div>
          </div>
          <div className={cx("w-24 shrink-0 font-medium", tone[s.status])}>{dayStatusLabel[s.status]}</div>
          <SourceBadge source={s.source} />
          <div className="tabular min-w-0 flex-1 truncate text-xs text-muted">
            {s.results.map((r) => `${r.name} ${r.repsDone}/${r.repsPrescribed}`).join(" · ")}
          </div>
        </li>
      ))}
    </ul>
  );
}

// ---------------------------------------------------------------- columna lateral

function DeviceCard({ p, onChange }: { p: PatientDetail; onChange: () => void }) {
  const devices = useSWR<Device[]>(p.device ? null : "/devices", fetcher);
  const [selected, setSelected] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const free = devices.data?.filter((d) => d.status === "AVAILABLE") ?? [];

  async function act(fn: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await fn();
      onChange();
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card title={<span className="inline-flex items-center gap-1.5"><Watch className="size-4" /> Reloj</span>}>
      {p.device ? (
        <div className="space-y-3 text-sm">
          <div className="font-mono text-lg font-semibold">{p.device.bleName}</div>
          <div className="grid grid-cols-2 gap-2 text-xs text-muted">
            <span className="inline-flex items-center gap-1">
              <Battery className="size-3.5" /> {p.device.lastBattery == null ? "—" : `${p.device.lastBattery}%`}
            </span>
            <span>Visto: {p.device.lastSeenAt ? relativeDay(p.device.lastSeenAt) : "nunca"}</span>
          </div>
          <p className="text-xs text-muted">Su apego es <b className="text-verified">verificado</b>: lo cuenta el reloj.</p>
          <Button variant="secondary" className="w-full" loading={busy} onClick={() => act(() => post(`/devices/${p.device!.id}/return`))}>
            Registrar devolución
          </Button>
        </div>
      ) : (
        <div className="space-y-3 text-sm">
          <p className="text-xs text-muted">Sin reloj: su apego es <b className="text-reported">reportado</b> por el paciente.</p>
          {free.length ? (
            <>
              <select className={inputClass} value={selected} onChange={(e) => setSelected(e.target.value)}>
                <option value="">Elegir reloj disponible…</option>
                {free.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.bleName}
                  </option>
                ))}
              </select>
              <Button className="w-full" disabled={!selected} loading={busy} onClick={() => act(() => post(`/devices/${selected}/assign`, { patientId: p.id }))}>
                Prestar reloj
              </Button>
            </>
          ) : (
            <p className="text-xs text-muted">No hay relojes disponibles.</p>
          )}
        </div>
      )}
      {error ? <div className="mt-3"><ErrorBox error={error} /></div> : null}
    </Card>
  );
}

function AppCard({ p, onChange }: { p: PatientDetail; onChange: () => void }) {
  const [busy, setBusy] = useState(false);
  const expired = p.invite && new Date(p.invite.expiresAt) < new Date();
  return (
    <Card title={<span className="inline-flex items-center gap-1.5"><Smartphone className="size-4" /> App del paciente</span>}>
      <div className="space-y-3 text-sm">
        <p className={cx("text-xs font-medium", p.appLinked ? "text-ok" : "text-muted")}>{p.appLinked ? "✓ El paciente ya entró a la app" : "El paciente aún no entra a la app"}</p>
        {p.invite && !expired ? (
          <div className="flex flex-col items-center gap-2 rounded-lg bg-surface-2 p-4">
            <QRCodeSVG value={p.invite.qr} size={140} marginSize={1} />
            <div className="font-mono text-2xl font-semibold tracking-[0.2em]">{p.invite.code}</div>
            <div className="text-xs text-muted">Vence el {shortDate(p.invite.expiresAt)}</div>
          </div>
        ) : (
          <p className="text-xs text-muted">{expired ? "El código venció." : "Sin código de invitación."}</p>
        )}
        <Button
          variant="secondary"
          className="w-full"
          loading={busy}
          onClick={async () => {
            setBusy(true);
            await post(`/patients/${p.id}/invite`).finally(() => setBusy(false));
            onChange();
          }}
        >
          <RefreshCw className="size-4" /> Nuevo código
        </Button>
      </div>
    </Card>
  );
}

function PrescriptionCard({ p, onChange }: { p: PatientDetail; onChange: () => void }) {
  const rx = p.prescription;
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<RxDraft | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  function startEdit() {
    setDraft({
      frequencyPerWeek: rx?.frequencyPerWeek ?? 5,
      notes: rx?.notes ?? "",
      items: rx?.items.map(({ exerciseId, sets, reps, restSec }) => ({ exerciseId, sets, reps, restSec })) ?? [{ exerciseId: 1, sets: 3, reps: 10, restSec: 45 }],
    });
    setEditing(true);
  }

  async function save() {
    if (!draft) return;
    setBusy(true);
    setError(null);
    try {
      await post(`/patients/${p.id}/prescriptions`, draftToBody(draft));
      setEditing(false);
      onChange();
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card
      title="Prescripción"
      action={
        !editing && (
          <button onClick={startEdit} className="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline">
            <Pencil className="size-3.5" /> Cambiar
          </button>
        )
      }
    >
      {editing && draft ? (
        <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/30 p-4 pt-16">
          <div className="w-full max-w-2xl space-y-4 rounded-xl border border-border bg-surface p-6 shadow-xl">
            <h3 className="text-lg font-semibold">Cambiar prescripción</h3>
            <PrescriptionEditor value={draft} onChange={setDraft} showTemplates={false} />
            <p className="text-xs text-muted">El cambio queda en el historial con fecha y autor. El paciente lo ve la próxima vez que abra la app.</p>
            {error ? <ErrorBox error={error} /> : null}
            <div className="flex justify-end gap-2">
              <Button variant="secondary" onClick={() => setEditing(false)}>
                Cancelar
              </Button>
              <Button loading={busy} onClick={save}>
                Guardar
              </Button>
            </div>
          </div>
        </div>
      ) : null}
      {rx ? (
        <div className="space-y-3 text-sm">
          {rx.template && <div className="text-xs text-muted">{rx.template.name}</div>}
          <ul className="space-y-1.5">
            {rx.items.map((i) => (
              <li key={i.id} className="flex justify-between gap-2">
                <span>{i.exercise.name}</span>
                <span className="tabular text-muted">
                  {i.sets}×{i.reps}
                </span>
              </li>
            ))}
          </ul>
          <div className="text-xs text-muted">
            {rx.frequencyPerWeek} días por semana · desde el {shortDate(rx.startDate)}
          </div>
          {rx.notes && <div className="rounded-md bg-surface-2 p-2 text-xs">{rx.notes}</div>}
          {p.prescriptionHistory.length > 1 && (
            <details className="text-xs text-muted">
              <summary className="cursor-pointer">Historial de cambios ({p.prescriptionHistory.length})</summary>
              <ul className="mt-2 space-y-2">
                {p.prescriptionHistory.map((h) => (
                  <li key={h.id}>
                    <b>{shortDate(h.createdAt)}</b> · {h.createdBy}
                    {h.active && " · actual"}
                    <div>{h.items.join(", ")}</div>
                  </li>
                ))}
              </ul>
            </details>
          )}
        </div>
      ) : (
        <p className="text-sm text-muted">Sin prescripción activa.</p>
      )}
    </Card>
  );
}

function DischargeButton({ id }: { id: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  return (
    <Button
      variant="danger"
      className="w-full"
      loading={busy}
      onClick={async () => {
        if (!confirm("¿Dar de alta al paciente? Se archiva y su reloj regresa a la clínica para limpieza.")) return;
        setBusy(true);
        await post(`/patients/${id}/discharge`).finally(() => setBusy(false));
        router.replace("/pacientes");
      }}
    >
      Dar de alta
    </Button>
  );
}
