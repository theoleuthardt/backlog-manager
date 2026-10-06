import { useEffect } from "react";

/** Sets the document title for its route. */
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
