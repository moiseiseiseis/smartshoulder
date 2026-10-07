"use client";

import { Plus, Trash2 } from "lucide-react";
import useSWR from "swr";
import { fetcher } from "@/lib/api";
import type { Exercise, Template } from "@/lib/types";
import { Field, inputClass } from "./ui";

export interface RxItem {
  exerciseId: number;
  sets: number;
  reps: number;
  restSec: number;
}

export interface RxDraft {
  templateId?: string;
  frequencyPerWeek: number;
  notes: string;
  items: RxItem[];
}

export function draftFromTemplate(t: Template): RxDraft {
  return {
    templateId: t.id,
    frequencyPerWeek: t.frequencyPerWeek,
    notes: "",
    items: t.items.map(({ exerciseId, sets, reps, restSec }) => ({ exerciseId, sets, reps, restSec })),
  };
}

/** Solo se pueden prescribir ejercicios que el modelo sabe reconocer (catálogo, contexto/05). */
export function PrescriptionEditor({ value, onChange, showTemplates = true }: { value: RxDraft; onChange: (v: RxDraft) => void; showTemplates?: boolean }) {
  const { data: exercises } = useSWR<Exercise[]>("/exercises", fetcher);
  const { data: templates } = useSWR<Template[]>("/templates", fetcher);

  const setItem = (i: number, patch: Partial<RxItem>) => onChange({ ...value, items: value.items.map((it, j) => (j === i ? { ...it, ...patch } : it)) });
  const used = new Set(value.items.map((i) => i.exerciseId));
  const nextFree = exercises?.find((e) => !used.has(e.id));

  return (
    <div className="space-y-4">
      {showTemplates && (
        <div>
          <div className="mb-2 text-sm font-medium">Partir de una plantilla</div>
          <div className="grid gap-2 sm:grid-cols-2">
            {templates?.map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => onChange(draftFromTemplate(t))}
                className={`rounded-lg border p-3 text-left text-sm ${value.templateId === t.id ? "border-primary bg-primary-soft" : "border-border hover:bg-surface-2"}`}
              >
                <div className="font-medium">{t.name}</div>
                <div className="mt-0.5 text-xs text-muted">
                  {t.items.length} ejercicios · {t.frequencyPerWeek} días por semana
                </div>
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-border">
        <table className="w-full min-w-[520px] text-sm">
          <thead className="bg-surface-2 text-left text-xs text-muted">
            <tr>
              <th className="px-3 py-2">Ejercicio</th>
              <th className="w-20 px-3 py-2">Series</th>
              <th className="w-20 px-3 py-2">Reps</th>
              <th className="w-28 px-3 py-2">Descanso (s)</th>
              <th className="w-10" />
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {value.items.map((it, i) => (
              <tr key={i}>
                <td className="px-3 py-2">
                  <select className={inputClass} value={it.exerciseId} onChange={(e) => setItem(i, { exerciseId: Number(e.target.value) })}>
                    {exercises?.map((e) => (
                      <option key={e.id} value={e.id} disabled={used.has(e.id) && e.id !== it.exerciseId}>
                        {e.name}
                      </option>
                    ))}
                  </select>
                </td>
                {(["sets", "reps", "restSec"] as const).map((k) => (
                  <td key={k} className="px-3 py-2">
                    <input
                      type="number"
                      min={k === "restSec" ? 0 : 1}
                      max={k === "sets" ? 10 : k === "reps" ? 50 : 600}
                      className={`${inputClass} tabular`}
                      value={it[k]}
                      onChange={(e) => setItem(i, { [k]: Number(e.target.value) })}
                    />
                  </td>
                ))}
                <td className="px-2">
                  <button
                    type="button"
                    aria-label="Quitar ejercicio"
                    disabled={value.items.length === 1}
                    onClick={() => onChange({ ...value, items: value.items.filter((_, j) => j !== i) })}
                    className="rounded p-1.5 text-muted hover:bg-danger-soft hover:text-danger disabled:opacity-30"
                  >
                    <Trash2 className="size-4" />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {nextFree && (
        <button
          type="button"
          onClick={() =>
            onChange({ ...value, items: [...value.items, { exerciseId: nextFree.id, sets: nextFree.defaultSets, reps: nextFree.defaultReps, restSec: nextFree.defaultRestSec }] })
          }
          className="inline-flex items-center gap-1.5 text-sm font-medium text-primary hover:underline"
        >
          <Plus className="size-4" /> Agregar ejercicio
        </button>
      )}

      <div className="grid gap-4 sm:grid-cols-[180px_1fr]">
        <Field label="Días por semana">
          <input
            type="number"
            min={1}
            max={14}
            className={`${inputClass} tabular`}
            value={value.frequencyPerWeek}
            onChange={(e) => onChange({ ...value, frequencyPerWeek: Number(e.target.value) })}
          />
        </Field>
        <Field label="Notas para el paciente (opcional)">
          <input className={inputClass} maxLength={500} value={value.notes} onChange={(e) => onChange({ ...value, notes: e.target.value })} placeholder="p. ej. sin dolor por encima de 4/10" />
        </Field>
      </div>
    </div>
  );
}

export function draftToBody(d: RxDraft) {
  return { templateId: d.templateId, frequencyPerWeek: d.frequencyPerWeek, notes: d.notes || undefined, items: d.items };
}
