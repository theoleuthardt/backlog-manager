import Image from "next/image";
import Link from "next/link";
import { UniverseBackground } from "components/UniverseBackground";

interface AuthCardProps {
  title: string;
  description: string;
  children: React.ReactNode;
}

/**
 * Shared shell of the auth pages: the landing page's background with a
 * centred, themed card carrying the app mark, a headline and a short
 * description above the page-specific form or actions.
 */
export const AuthCard = ({ title, description, children }: AuthCardProps) => (
  <div className="relative min-h-screen overflow-hidden">
    <UniverseBackground />
    <main className="drop-in relative z-10 flex min-h-screen flex-col items-center justify-center gap-6 px-4 py-12">
      <Link
        href="/"
        className="text-foreground flex items-center gap-3 text-3xl font-bold transition-opacity hover:opacity-80"
      >
        <Image
          src="/logo_mana.png"
          alt=""
          width={56}
          height={56}
          unoptimized
          className="themed-icon h-14 w-14"
        />
        Backlog-Manager
      </Link>
      <section className="bg-card text-card-foreground border-border surface-glow w-full max-w-md rounded-2xl border p-8 shadow-lg">
        <h1 className="text-center text-3xl font-extrabold tracking-tight">
          {title}
        </h1>
        <p className="text-muted-foreground mt-2 mb-6 text-center text-sm">
          {description}
        </p>
        {children}
      </section>
    </main>
  </div>
);
