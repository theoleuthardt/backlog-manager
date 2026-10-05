import { useEffect } from "react";

/**
 * Wrapper of every route: sets the document title and plays the short
 * slide-in (`route-in`, see globals.css) the pages had as a Next.js
 * template. Each navigation mounts a fresh route element, so the
 * animation runs once per page change.
 */
export function RoutePage({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  useEffect(() => {
    document.title = title;
  }, [title]);

  return <div className="route-in">{children}</div>;
}
