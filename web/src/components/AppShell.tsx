"use client";

import { Building2, LogOut, Users, Watch } from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useSyncExternalStore, type ReactNode } from "react";
import { auth, type SessionUser } from "@/lib/api";
import { cx } from "./ui";

const NAV = [
  { href: "/pacientes", label: "Pacientes", icon: Users },
  { href: "/relojes", label: "Relojes", icon: Watch },
  { href: "/clinica", label: "Clínica", icon: Building2 },
];

function subscribeStorage(cb: () => void) {
  window.addEventListener("storage", cb);
  return () => window.removeEventListener("storage", cb);
}

export function AppShell({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  // La sesión vive en localStorage: se lee como fuente externa (en el servidor no hay sesión).
  const raw = useSyncExternalStore(subscribeStorage, () => (auth.token() ? JSON.stringify(auth.user()) : "null"), () => undefined);
  const user = useMemo<SessionUser | null>(() => (raw ? JSON.parse(raw) : null), [raw]);

  useEffect(() => {
    if (raw === "null") router.replace("/login");
  }, [raw, router]);

  if (!user) return null;

  return (
    <div className="flex min-h-screen">
      <aside className="sticky top-0 hidden h-screen w-56 shrink-0 flex-col border-r border-border bg-surface md:flex">
        <div className="px-5 py-5">
          <div className="text-base font-bold tracking-tight text-primary">SmartShoulder</div>
          <div className="truncate text-xs text-muted">{user.clinic.name}</div>
        </div>
        <nav className="flex-1 space-y-0.5 px-3">
          {NAV.map(({ href, label, icon: Icon }) => (
            <Link
              key={href}
              href={href}
              className={cx(
                "flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm font-medium",
                pathname.startsWith(href) ? "bg-primary-soft text-primary" : "text-muted hover:bg-surface-2 hover:text-text",
              )}
            >
              <Icon className="size-4" /> {label}
            </Link>
          ))}
        </nav>
        <div className="border-t border-border p-3">
          <div className="truncate px-2 text-sm font-medium">{user.name}</div>
          <button
            onClick={() => {
              auth.clear();
              router.replace("/login");
            }}
            className="mt-1 flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-sm text-muted hover:bg-surface-2"
          >
            <LogOut className="size-4" /> Cerrar sesión
          </button>
        </div>
      </aside>

      {/* Navegación compacta en pantallas chicas */}
      <div className="flex min-w-0 flex-1 flex-col">
        <nav className="flex gap-1 overflow-x-auto border-b border-border bg-surface px-4 py-2 md:hidden">
          {NAV.map(({ href, label }) => (
            <Link key={href} href={href} className={cx("rounded-md px-3 py-1.5 text-sm", pathname.startsWith(href) ? "bg-primary-soft text-primary" : "text-muted")}>
              {label}
            </Link>
          ))}
        </nav>
        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6 md:px-8">{children}</main>
      </div>
    </div>
  );
}
