"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, ErrorBox, Field, inputClass } from "@/components/ui";
import { auth, post, type SessionUser } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<unknown>(null);
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const r = await post<{ token: string; user: SessionUser }>("/auth/login", { email, password });
      auth.save(r.token, r.user);
      router.replace("/pacientes");
    } catch (err) {
      setError(err);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <form onSubmit={submit} className="w-full max-w-sm space-y-5 rounded-2xl border border-border bg-surface p-8">
        <div>
          <div className="text-xl font-bold tracking-tight text-primary">SmartShoulder</div>
          <p className="mt-1 text-sm text-muted">Sabe qué pacientes sí hacen sus ejercicios en casa.</p>
        </div>
        <Field label="Correo">
          <input className={inputClass} type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </Field>
        <Field label="Contraseña">
          <input className={inputClass} type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </Field>
        {error ? <ErrorBox error={error} /> : null}
        <Button type="submit" loading={loading} className="w-full">
          Entrar
        </Button>
      </form>
    </div>
  );
}
