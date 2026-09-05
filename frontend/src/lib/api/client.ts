import createClient from "openapi-fetch";

import { env } from "~/env";

import type { paths } from "./schema";

/**
 * Type-safe fetch client for the Litestar backend, generated from its
 * OpenAPI schema (see Taskfile's `backend:openapi` + `frontend:generate-api-types`
 * tasks - re-run both after changing a backend route's request/response
 * shape). Not yet wired into any component: the actual tRPC -> REST
 * migration is a separate, later step.
 */
export const apiClient = createClient<paths>({
  baseUrl: env.NEXT_PUBLIC_API_URL,
});
