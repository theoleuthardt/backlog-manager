import { parseApiUrl } from "~/lib/apiUrl";

const result = parseApiUrl(
  import.meta.env.NEXT_PUBLIC_API_URL,
  import.meta.env.PROD,
);

if (!result.success) {
  throw new Error(`Invalid NEXT_PUBLIC_API_URL: ${result.message}`);
}

export const env = { NEXT_PUBLIC_API_URL: result.url };
