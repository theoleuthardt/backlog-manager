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
        className="text-muted-foreground hover:text-foreground flex items-center gap-2 text-sm transition-colors"
      >
        <Image
          src="/favicon.ico"
          alt=""
          width={20}
          height={20}
          unoptimized
          className="rounded"
        />
        Backlog Manager
      </Link>
      <section className="bg-card text-card-foreground border-border surface-glow w-full max-w-md rounded-2xl border p-8 shadow-lg">
        <h1 className="text-3xl font-extrabold tracking-tight">{title}</h1>
        <p className="text-muted-foreground mt-2 mb-6 text-sm">{description}</p>
        {children}
      </section>
    </main>
  </div>
);
