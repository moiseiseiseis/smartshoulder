"use client";

import { AlertTriangle, Hand, Loader2, Watch } from "lucide-react";
import type { ButtonHTMLAttributes, ReactNode } from "react";
import { alertText } from "@/lib/format";
import type { Alert, Source } from "@/lib/types";

export function cx(...c: (string | false | null | undefined)[]) {
  return c.filter(Boolean).join(" ");
}

export function Card({ children, className, title, action }: { children: ReactNode; className?: string; title?: ReactNode; action?: ReactNode }) {
  return (
    <section className={cx("rounded-xl border border-border bg-surface", className)}>
      {(title || action) && (
        <header className="flex items-center justify-between gap-3 border-b border-border px-5 py-3">
          <h2 className="text-sm font-semibold">{title}</h2>
          {action}
        </header>
      )}
      <div className="p-5">{children}</div>
    </section>
  );
}

type Variant = "primary" | "secondary" | "ghost" | "danger";

export function Button({ variant = "primary", loading, className, children, ...props }: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; loading?: boolean }) {
  const styles: Record<Variant, string> = {
    primary: "bg-primary text-white hover:bg-primary-hover",
    secondary: "border border-border bg-surface hover:bg-surface-2",
    ghost: "hover:bg-surface-2",
    danger: "border border-danger/30 bg-surface text-danger hover:bg-danger-soft",
  };
  return (
    <button
      {...props}
      disabled={props.disabled || loading}
      className={cx(
        "inline-flex items-center justify-center gap-2 rounded-lg px-3.5 py-2 text-sm font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-50",
        styles[variant],
        className,
      )}
    >
      {loading && <Loader2 className="size-4 animate-spin" />}
      {children}
    </button>
  );
}

/** Origen del dato de apego. Siempre ícono + texto. */
export function SourceBadge({ source, long }: { source: Source; long?: boolean }) {
  const verified = source === "VERIFIED";
  const Icon = verified ? Watch : Hand;
  const label = verified ? (long ? "Verificado por el dispositivo" : "Verificado") : long ? "Reportado por el paciente" : "Reportado";
  return (
    <span
      className={cx(
        "inline-flex items-center gap-1 whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-medium",
        verified ? "bg-verified-soft text-verified" : "bg-reported-soft text-reported",
      )}
    >
      <Icon className="size-3.5" aria-hidden />
      {label}
    </span>
  );
}

export function AlertChip({ alert }: { alert: Alert }) {
  return (
    <span className="inline-flex items-center gap-1 whitespace-nowrap rounded-md bg-danger-soft px-2 py-0.5 text-xs font-medium text-danger">
      <AlertTriangle className="size-3.5" aria-hidden />
      {alertText(alert)}
    </span>
  );
}

export function DemoTag() {
  return <span className="rounded border border-border px-1.5 py-px text-[10px] font-semibold uppercase tracking-wide text-muted">Demo</span>;
}

export function Stat({ label, value, hint, tone }: { label: string; value: ReactNode; hint?: ReactNode; tone?: "verified" | "reported" | "danger" }) {
  const color = tone === "verified" ? "text-verified" : tone === "reported" ? "text-reported" : tone === "danger" ? "text-danger" : "";
  return (
    <div className="min-w-0">
      <div className="text-xs font-medium text-muted">{label}</div>
      <div className={cx("tabular mt-1 text-2xl font-semibold", color)}>{value}</div>
      {hint && <div className="mt-0.5 text-xs text-muted">{hint}</div>}
    </div>
  );
}

export function Spinner({ label = "Cargando…" }: { label?: string }) {
  return (
    <div className="flex items-center gap-2 p-8 text-sm text-muted">
      <Loader2 className="size-4 animate-spin" /> {label}
    </div>
  );
}

export function ErrorBox({ error }: { error: unknown }) {
  return (
    <div className="rounded-lg border border-danger/30 bg-danger-soft p-4 text-sm text-danger">
      {error instanceof Error ? error.message : "Algo salió mal."}
    </div>
  );
}

export function PctBar({ value, tone = "verified" }: { value: number | null; tone?: "verified" | "reported" }) {
  const v = value ?? 0;
  const color = v < 50 ? "bg-danger" : tone === "verified" ? "bg-verified" : "bg-reported";
  return (
    <div className="flex items-center gap-2">
      <div className="h-1.5 w-16 overflow-hidden rounded-full bg-surface-2">
        <div className={cx("h-full rounded-full", color)} style={{ width: `${v}%` }} />
      </div>
      <span className={cx("tabular w-10 text-sm font-semibold", v < 50 && value !== null && "text-danger")}>{value === null ? "—" : `${v}%`}</span>
    </div>
  );
}

export const inputClass =
  "w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20";

export function Field({ label, children, hint }: { label: string; children: ReactNode; hint?: string }) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-medium">{label}</span>
      {children}
      {hint && <span className="mt-1 block text-xs text-muted">{hint}</span>}
    </label>
  );
}

/** Etiqueta regulatoria (contexto/04 §4). */
export function DataDisclaimer() {
  return (
    <p className="text-xs text-muted">
      Datos de ejecución registrados por el dispositivo o reportados por el paciente. No constituyen una evaluación clínica.
    </p>
  );
}
