import { type Metadata } from "next";

import { TRPCReactProvider } from "~/trpc/react";

export const metadata: Metadata = {
  title: "Create Account",
  description: "Create your Backlog Manager account",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function RegisterLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <TRPCReactProvider>{children}</TRPCReactProvider>;
}
