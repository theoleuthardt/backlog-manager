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

type TokenClearedListener = () => void;
const tokenClearedListeners = new Set<TokenClearedListener>();

/**
 * Notified whenever the token is cleared, whether by an explicit logout or
 * by the apiClient's response middleware reacting to a 401 - AuthContext
 * uses this to drop its `user` state and clear the React Query cache even
 * when the token expires mid-session, not just on an explicit logout()
 * call. Returns an unsubscribe function.
 */
export function onTokenCleared(listener: TokenClearedListener): () => void {
  tokenClearedListeners.add(listener);
  return () => tokenClearedListeners.delete(listener);
}

export function clearToken(): void {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(TOKEN_STORAGE_KEY);
  tokenClearedListeners.forEach((listener) => listener());
}
