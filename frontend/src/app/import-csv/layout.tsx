import { type Metadata } from "next";

export const metadata: Metadata = {
  title: "Import CSV",
  description: "Import your backlog from a CSV file",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function ImportCSVLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <>{children}</>;
}


