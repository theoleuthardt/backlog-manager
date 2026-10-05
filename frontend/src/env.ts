import { z } from "zod";

/**
 * The API base URL is baked in at build time. In a production build it
 * must be https, or the Bearer token travels in cleartext; loopback hosts
 * (a local container build, the dev setup) are exempt.
 */
const productionApiUrl = z
  .string()
  .url()
  .refine(
    (url) => {
      const parsed = new URL(url);
      const isLoopback = ["localhost", "127.0.0.1", "[::1]"].includes(
        parsed.hostname,
      );
      return parsed.protocol === "https:" || isLoopback;
    },
    {
      message:
        "NEXT_PUBLIC_API_URL must use https in production, or the Bearer token travels in cleartext (loopback hosts like localhost are exempt)",
    },
  );

const developmentApiUrl = z.string().url().default("http://localhost:8000");

const rawApiUrl = import.meta.env.NEXT_PUBLIC_API_URL;
const parsed = (
  import.meta.env.PROD ? productionApiUrl : developmentApiUrl
).safeParse(rawApiUrl === "" ? undefined : rawApiUrl);

if (!parsed.success) {
  throw new Error(
    `Invalid NEXT_PUBLIC_API_URL: ${parsed.error.issues.map((issue) => issue.message).join(", ")}`,
  );
}

export const env = { NEXT_PUBLIC_API_URL: parsed.data };
