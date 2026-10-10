import React from "react";
import { useIsTauri } from "~/hooks/useIsTauri";
import { openExternalLink } from "~/lib/externalLink";

/**
 * An anchor to a page outside the app. In the browser it opens a new tab; the
 * Tauri webview ignores `target="_blank"`, so there the click goes to the
 * system browser through the opener plugin instead.
 */
export const ExternalAnchor = ({
  href,
  onClick,
  ...props
}: React.AnchorHTMLAttributes<HTMLAnchorElement> & { href: string }) => {
  const isTauri = useIsTauri();

  const handleClick = (event: React.MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event);
    if (!isTauri || event.defaultPrevented) return;
    event.preventDefault();
    void openExternalLink(href, async (url) => {
      const { openUrl } = await import("@tauri-apps/plugin-opener");
      await openUrl(url);
    });
  };

  return (
    <a
      {...props}
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      onClick={handleClick}
    />
  );
};
