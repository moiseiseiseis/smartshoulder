"use client";

export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

const TOKEN_KEY = "ss_token";
const USER_KEY = "ss_user";

export interface SessionUser {
  id: string;
  name: string;
  role: "PHYSIO" | "CLINIC_ADMIN";
  clinic: { id: string; name: string };
}

function storage(): Storage | null {
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

export const auth = {
  token: () => storage()?.getItem(TOKEN_KEY) ?? null,
  user: (): SessionUser | null => {
    const raw = storage()?.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as SessionUser) : null;
  },
  save(token: string, user: SessionUser) {
    storage()?.setItem(TOKEN_KEY, token);
    storage()?.setItem(USER_KEY, JSON.stringify(user));
  },
  clear() {
    storage()?.removeItem(TOKEN_KEY);
    storage()?.removeItem(USER_KEY);
  },
};

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = auth.token();
  const res = await fetch(API_URL + path, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  });
  if (res.status === 401 && !path.startsWith("/auth/")) {
    auth.clear();
    window.location.href = "/login";
    throw new ApiError(401, "Sesión expirada");
  }
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    const msg = Array.isArray(body.message) ? body.message.join(" · ") : body.message;
    throw new ApiError(res.status, msg || `Error ${res.status}`);
  }
  const type = res.headers.get("content-type") ?? "";
  return (type.includes("application/json") ? res.json() : res.text()) as Promise<T>;
}

export const post = <T>(path: string, body?: unknown) =>
  api<T>(path, { method: "POST", body: body ? JSON.stringify(body) : undefined });

export const patch = <T>(path: string, body?: unknown) =>
  api<T>(path, { method: "PATCH", body: body ? JSON.stringify(body) : undefined });

/** fetcher para SWR */
export const fetcher = <T>(path: string) => api<T>(path);

/** Descarga un archivo autenticado (export CSV). */
export async function download(path: string, filename: string) {
  const text = await api<string>(path);
  const url = URL.createObjectURL(new Blob([text], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
