import { type Metadata } from "next";

import { RequireAuth } from "components";

export const metadata: Metadata = {
  title: "Account",
  description: "Manage your Backlog Manager account",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function AccountLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <RequireAuth>{children}</RequireAuth>;
}
