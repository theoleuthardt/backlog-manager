import { useEffect } from "react";

/** Sets the document title and plays the page slide-in (`route-in`, globals.css). */
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
