import { type Metadata } from "next";

export const metadata: Metadata = {
  title: "Dashboard",
  description: "Your Backlog Manager Dashboard",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function DashboardLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <>{children}</>;
}
