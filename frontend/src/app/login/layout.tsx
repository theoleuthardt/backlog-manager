import { type Metadata } from "next";

import { TRPCReactProvider } from "~/trpc/react";

export const metadata: Metadata = {
  title: "Login",
  description: "Login to your Backlog Manager account",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

export default function LoginLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <TRPCReactProvider>{children}</TRPCReactProvider>;
}
