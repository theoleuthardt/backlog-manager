const TOKEN_STORAGE_KEY = "backlog-manager.access-token";

/**
 * The backend authenticates via a Bearer token, not a cookie (see
 * backend/src/backlog_manager_backend/app.py's CORS comment) - localStorage
 * is the natural place to keep it for a client-rendered SPA, and works
 * the same way for a future Tauri build. Guarded for SSR: Next.js still
 * renders this module's importers on the server for the initial HTML.
 */
export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(TOKEN_STORAGE_KEY);
}

export function setToken(token: string): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(TOKEN_STORAGE_KEY, token);
}

export function clearToken(): void {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(TOKEN_STORAGE_KEY);
}
