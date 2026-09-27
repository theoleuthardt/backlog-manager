import "../styles/globals.css";

import { type Metadata } from "next";
import { Geist } from "next/font/google";

import { ApiProvider } from "~/lib/api/provider";
import { AuthProvider } from "~/app/context/AuthContext";
import { Toaster } from "~/components/ui/sonner";
import { CSVImportProvider } from "~/app/context/CSVImportContext";
import { ThemeProvider } from "~/app/context/ThemeContext";
import { THEME_CACHE_KEY } from "~/lib/themes";

export const metadata: Metadata = {
  title: "Backlog-Manager",
  description: "A manager for your gaming backlog",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

/**
 * Runs before first paint: re-applies the theme that ThemeProvider
 * cached in localStorage so a reload never flashes the default theme.
 */
const THEME_BOOT_SCRIPT = `try{var t=JSON.parse(localStorage.getItem(${JSON.stringify(THEME_CACHE_KEY)}));if(t&&t.variables){var r=document.documentElement;for(var k in t.variables){r.style.setProperty(k,t.variables[k])}r.dataset.theme=t.dataTheme;r.style.colorScheme=t.colorScheme}}catch(e){}`;

const geist = Geist({
  subsets: ["latin"],
  variable: "--font-geist-sans",
});

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${geist.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_BOOT_SCRIPT }} />
      </head>
      <body>
        <ApiProvider>
          <AuthProvider>
            <ThemeProvider>
              <CSVImportProvider>{children}</CSVImportProvider>
            </ThemeProvider>
          </AuthProvider>
        </ApiProvider>
        <Toaster />
      </body>
    </html>
  );
}
