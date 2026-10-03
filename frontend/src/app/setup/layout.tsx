import { type Metadata } from "next";

import { RequireAuth } from "components";

export const metadata: Metadata = {
  title: "Setup",
  description: "Set up your Backlog Manager account",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function SetupLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <RequireAuth>{children}</RequireAuth>;
}
