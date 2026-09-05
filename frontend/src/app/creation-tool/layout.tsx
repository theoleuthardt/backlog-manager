import { type Metadata } from "next";

export const metadata: Metadata = {
  title: "Creation Tool",
  description: "Your Backlog Manager Creation Tool",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function DashboardLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <>{children}</>;
}
