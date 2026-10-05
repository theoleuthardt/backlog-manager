import { z } from "zod";

const LOOPBACK_HOSTS = ["localhost", "127.0.0.1", "[::1]"];

const productionApiUrl = z
  .string()
  .url()
  .refine(
    (url) => {
      const parsed = new URL(url);
      return (
        parsed.protocol === "https:" || LOOPBACK_HOSTS.includes(parsed.hostname)
      );
    },
    {
      message:
        "NEXT_PUBLIC_API_URL must use https in production, or the Bearer token travels in cleartext (loopback hosts like localhost are exempt)",
    },
  );

const developmentApiUrl = z.string().url().default("http://localhost:8000");

export type ApiUrlResult =
  | { success: true; url: string }
  | { success: false; message: string };

/**
 * Validates the backend base URL baked into the build. A production build
 * requires it and insists on https (loopback hosts exempt); development
 * falls back to the local backend. An empty value counts as unset.
 */
export function parseApiUrl(
  raw: string | undefined,
  production: boolean,
): ApiUrlResult {
  const result = (production ? productionApiUrl : developmentApiUrl).safeParse(
    raw === "" ? undefined : raw,
  );
  if (result.success) return { success: true, url: result.data };
  return {
    success: false,
    message: result.error.issues.map((issue) => issue.message).join(", "),
  };
}
