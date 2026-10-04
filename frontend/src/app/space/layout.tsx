import { type Metadata } from "next";

import { RequireAuth } from "components";

export const metadata: Metadata = {
  title: "Shared space",
  description: "Your shared Backlog Manager space",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function SpaceLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <RequireAuth>{children}</RequireAuth>;
}
