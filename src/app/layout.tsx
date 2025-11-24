import "../styles/globals.css";

import { type Metadata } from "next";
import { Geist } from "next/font/google";

import { TRPCReactProvider } from "~/trpc/react";
import { Toaster } from "~/components/ui/sonner";
import { CSVImportProvider } from "~/app/context/CSVImportContext";

export const metadata: Metadata = {
  title: "Backlog-Manager",
  description: "A manager for your gaming backlog",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

const geist = Geist({
  subsets: ["latin"],
  variable: "--font-geist-sans",
});

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${geist.variable}`}>
      <body>
        <TRPCReactProvider>
          <CSVImportProvider>{children}</CSVImportProvider>
        </TRPCReactProvider>
        <Toaster />
      </body>
    </html>
  );
}
