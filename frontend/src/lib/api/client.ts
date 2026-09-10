import createClient from "openapi-fetch";

import { env } from "~/env";

import { clearToken, getToken } from "./token";
import type { paths } from "./schema";

/**
 * Type-safe fetch client for the Litestar backend, generated from its
 * OpenAPI schema (see Taskfile's `backend:openapi` + `frontend:generate-api-types`
 * tasks - re-run both after changing a backend route's request/response
 * shape).
 */
export const apiClient = createClient<paths>({
  baseUrl: env.NEXT_PUBLIC_API_URL,
});

/**
 * Attaches the stored Bearer token to every request. A 401 response here
 * always means "this token is no longer valid" (expired, or the user was
 * deleted) - the login endpoint itself never sends an Authorization
 * header, so it can't loop back into this branch - and clears the token.
 */
apiClient.use({
  onRequest({ request }) {
    const token = getToken();
    if (token) {
      request.headers.set("Authorization", `Bearer ${token}`);
    }
    return request;
  },
  onResponse({ response }) {
    if (response.status === 401) {
      clearToken();
    }
    return response;
  },
});

interface LitestarErrorBody {
  detail?: string;
}

/**
 * Every route handler in the backend responds with Litestar's default
 * `{status_code, detail, ...}` shape on error (see
 * litestar.exceptions.responses.ExceptionResponseContent) - this pulls
 * the human-readable `detail` out of it, since that's what should
 * actually be shown to the user (toasts, inline form errors, ...).
 */
export function apiErrorMessage(error: unknown, fallback: string): string {
  if (error && typeof error === "object" && "detail" in error) {
    const detail = (error as LitestarErrorBody).detail;
    if (typeof detail === "string" && detail.length > 0) {
      return detail;
    }
  }
  return fallback;
}
