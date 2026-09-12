import { type Metadata } from "next";

import { RequireAuth } from "components";

export const metadata: Metadata = {
  title: "Steam",
  description: "Sync your Steam library and wishlist",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function SteamLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <RequireAuth>{children}</RequireAuth>;
}