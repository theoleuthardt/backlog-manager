import { type Metadata } from "next";

import { RequireAuth } from "components";

export const metadata: Metadata = {
  title: "Theme Creator",
  description: "Create your own Backlog Manager theme",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function ThemesLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <RequireAuth>{children}</RequireAuth>;
}
