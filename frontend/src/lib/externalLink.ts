import { isHttpUrl } from "~/lib/safeUrl";

export async function openExternalLink(
  href: string,
  open: (url: string) => Promise<void>,
): Promise<void> {
  if (!isHttpUrl(href)) return;
  await open(href);
}
