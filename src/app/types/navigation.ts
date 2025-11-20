import type { JSX, ReactNode } from "react";

/**
 * Navigation link configuration
 */
export interface NavbarLink {
  id: number;
  href?: string;
  content?: JSX.Element;
  component?: ReactNode;
  action?: string;
  target?: string;
  type: "link" | "component";
}
