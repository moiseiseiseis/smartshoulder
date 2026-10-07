"use client";

import { ArrowLeft, Check, Hand, Watch } from "lucide-react";
import Link from "next/link";
import { QRCodeSVG } from "qrcode.react";
import { useState } from "react";
import useSWR from "swr";
import { PrescriptionEditor, draftFromTemplate, draftToBody, type RxDraft } from "@/components/PrescriptionEditor";
import { Button, Card, ErrorBox, Field, cx, inputClass } from "@/components/ui";
import { fetcher, post } from "@/lib/api";
import { shortDate } from "@/lib/format";
import type { Device, Template } from "@/lib/types";

const STEPS = ["Paciente", "Prescripción", "Reloj"];

interface Created {
  id: string;
  invite: { code: string; expiresAt: string; qr: string };
}

export default function NewPatientPage() {
  const [step, setStep] = useState(0);
  const [name, setName] = useState("");
  const [arm, setArm] = useState<"RIGHT" | "LEFT">("RIGHT");
  const [diagnosis, setDiagnosis] = useState("");
  const [rxDraft, setRx] = useState<RxDraft | null>(null);
  const [deviceId, setDeviceId] = useState<string>("");
  const [created, setCreated] = useState<Created | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  const { data: templates } = useSWR<Template[]>("/templates", fetcher);
  const { data: devices } = useSWR<Device[]>("/devices", fetcher);
  const free = devices?.filter((d) => d.status === "AVAILABLE") ?? [];

  // Hasta que el fisio edite, la prescripción propuesta es la primera plantilla.
  const rx = rxDraft ?? (templates?.length ? draftFromTemplate(templates[0]) : null);

  const canNext = step === 0 ? name.trim().length >= 2 && diagnosis.trim().length >= 2 : step === 1 ? !!rx?.items.length : true;

  async function submit() {
    if (!rx) return;
    setBusy(true);
    setError(null);
    try {
      const r = await post<Created>("/patients", {
        displayName: name.trim(),
        affectedArm: arm,
        diagnosis: diagnosis.trim(),
        prescription: draftToBody(rx),
        deviceId: deviceId || undefined,
      });
      setCreated(r);
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  }

  if (created) {
    const device = free.find((d) => d.id === deviceId);
    return (
      <div className="mx-auto max-w-lg space-y-5">
        <Card>
          <div className="flex flex-col items-center gap-4 text-center">
            <div className="flex size-10 items-center justify-center rounded-full bg-verified-soft text-verified">
              <Check className="size-5" />
            </div>
            <div>
              <h1 className="text-xl font-semibold">{name} ya está dado de alta</h1>
              <p className="mt-1 text-sm text-muted">Pídele que instale la app SmartShoulder y escanee este código.</p>
            </div>
            <QRCodeSVG value={created.invite.qr} size={200} marginSize={2} />
            <div className="font-mono text-3xl font-semibold tracking-[0.25em]">{created.invite.code}</div>
            <p className="text-xs text-muted">
              {device ? (
                <>
                  El código incluye el reloj <b className="font-mono">{device.bleName}</b>: la app lo emparejará sola.{" "}
                </>
              ) : (
                "Sin reloj: el paciente marcará sus sesiones a mano. "
              )}
              Vence el {shortDate(created.invite.expiresAt)}.
            </p>
          </div>
        </Card>
        <div className="flex justify-center gap-2">
          <Link href={`/pacientes/${created.id}`} className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-hover">
            Ver paciente
          </Link>
          <Link href="/pacientes" className="rounded-lg border border-border bg-surface px-4 py-2 text-sm font-medium hover:bg-surface-2">
            Volver a la lista
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl space-y-5">
      <Link href="/pacientes" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <ArrowLeft className="size-4" /> Pacientes
      </Link>
      <h1 className="text-2xl font-semibold tracking-tight">Nuevo paciente</h1>

      <ol className="flex gap-2">
        {STEPS.map((s, i) => (
          <li key={s} className={cx("flex flex-1 items-center gap-2 rounded-lg border px-3 py-2 text-sm", i === step ? "border-primary bg-primary-soft font-medium text-primary" : i < step ? "border-border text-text" : "border-border text-muted")}>
            <span className={cx("flex size-5 items-center justify-center rounded-full text-xs", i < step ? "bg-verified text-white" : "bg-surface-2")}>{i < step ? <Check className="size-3" /> : i + 1}</span>
            {s}
          </li>
        ))}
      </ol>

      <Card>
        {step === 0 && (
          <div className="space-y-4">
            <Field label="Nombre">
              <input className={inputClass} autoFocus value={name} onChange={(e) => setName(e.target.value)} maxLength={80} placeholder="Como lo verá en la lista" />
            </Field>
            <div>
              <div className="mb-1 text-sm font-medium">Hombro en rehabilitación</div>
              <div className="flex gap-2">
                {(["RIGHT", "LEFT"] as const).map((a) => (
                  <button key={a} type="button" onClick={() => setArm(a)} className={cx("flex-1 rounded-lg border px-3 py-2 text-sm", arm === a ? "border-primary bg-primary-soft font-medium text-primary" : "border-border")}>
                    {a === "RIGHT" ? "Derecho" : "Izquierdo"}
                  </button>
                ))}
              </div>
              <p className="mt-1 text-xs text-muted">El reloj se coloca en la muñeca de este brazo.</p>
            </div>
            <Field label="Diagnóstico o procedimiento" hint="Texto libre, solo para tu referencia.">
              <input className={inputClass} value={diagnosis} onChange={(e) => setDiagnosis(e.target.value)} maxLength={200} placeholder="p. ej. Reparación de manguito rotador" />
            </Field>
          </div>
        )}

        {step === 1 && rx && <PrescriptionEditor value={rx} onChange={setRx} />}

        {step === 2 && (
          <div className="space-y-3">
            <p className="text-sm text-muted">¿El paciente se lleva un reloj a casa?</p>
            <button type="button" onClick={() => setDeviceId("")} className={cx("flex w-full items-start gap-3 rounded-lg border p-3 text-left", !deviceId ? "border-primary bg-primary-soft" : "border-border hover:bg-surface-2")}>
              <Hand className="mt-0.5 size-5 text-reported" />
              <div>
                <div className="text-sm font-medium">Sin reloj · apego reportado</div>
                <div className="text-xs text-muted">El paciente marca sus series a mano en la app.</div>
              </div>
            </button>
            {free.map((d) => (
              <button key={d.id} type="button" onClick={() => setDeviceId(d.id)} className={cx("flex w-full items-start gap-3 rounded-lg border p-3 text-left", deviceId === d.id ? "border-primary bg-primary-soft" : "border-border hover:bg-surface-2")}>
                <Watch className="mt-0.5 size-5 text-verified" />
                <div>
                  <div className="text-sm font-medium">
                    Prestar <span className="font-mono">{d.bleName}</span> · apego verificado
                  </div>
                  <div className="text-xs text-muted">El reloj cuenta las repeticiones. Ha atendido a {d.patientsServed} pacientes.</div>
                </div>
              </button>
            ))}
            {!free.length && <p className="text-xs text-muted">No hay relojes disponibles en este momento.</p>}
          </div>
        )}
      </Card>

      {error ? <ErrorBox error={error} /> : null}
      <div className="flex justify-between">
        <Button variant="secondary" disabled={step === 0} onClick={() => setStep(step - 1)}>
          Atrás
        </Button>
        {step < 2 ? (
          <Button disabled={!canNext} onClick={() => setStep(step + 1)}>
            Siguiente
          </Button>
        ) : (
          <Button loading={busy} onClick={submit}>
            Dar de alta y generar código
          </Button>
        )}
      </div>
    </div>
  );
}
