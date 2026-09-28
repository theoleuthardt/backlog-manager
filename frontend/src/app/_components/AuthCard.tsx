"use client";
import Image from "next/image";
import Link from "next/link";
import { MotionConfig, motion } from "motion/react";
import { UniverseBackground } from "components/UniverseBackground";

interface AuthCardProps {
  title: string;
  description: string;
  children: React.ReactNode;
}

/**
 * Shared shell of the auth pages: the landing page's star background with
 * a floating app mark and a centred card in the same black/white
 * bordered style as the account cards, lit by a soft halo in the theme's
 * accent and glow colours. Motion honours the user's reduced-motion
 * setting.
 */
export const AuthCard = ({ title, description, children }: AuthCardProps) => (
  <MotionConfig reducedMotion="user">
    <div className="relative min-h-screen overflow-hidden">
      <UniverseBackground />
      <main className="relative z-10 flex min-h-screen flex-col items-center justify-center gap-8 px-4 py-12">
        <motion.div
          animate={{ y: [0, -32, 0], scale: [1, 1.1, 1] }}
          transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
        >
          <Link
            href="/"
            className="text-foreground flex items-center gap-3 text-3xl font-bold transition-opacity hover:opacity-80"
            style={{ textShadow: "0 0 18px var(--t-glow)" }}
          >
            <Image
              src="/logo_mana.png"
              alt=""
              width={56}
              height={56}
              unoptimized
              className="themed-icon h-14 w-14"
              style={{ filter: "drop-shadow(0 0 10px var(--t-glow))" }}
            />
            Backlog-Manager
          </Link>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, y: 24, scale: 0.97 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 0.5, ease: "easeOut" }}
          className="relative w-full max-w-md"
        >
          <div
            aria-hidden="true"
            className="absolute -inset-1 rounded-3xl opacity-50 blur-xl"
            style={{
              background:
                "linear-gradient(120deg, var(--t-accent), var(--t-glow), var(--t-accent))",
            }}
          />
          <section className="relative rounded-2xl border-2 border-white bg-black/85 p-8 text-white backdrop-blur-md">
            <h1
              className="text-center text-3xl font-extrabold tracking-tight"
              style={{ textShadow: "0 0 24px var(--t-glow)" }}
            >
              {title}
            </h1>
            <p className="mt-2 text-center text-sm text-gray-300">
              {description}
            </p>
            <div
              aria-hidden="true"
              className="mt-5 mb-6 h-px"
              style={{
                background:
                  "linear-gradient(to right, transparent, var(--t-glow), transparent)",
              }}
            />
            {children}
          </section>
        </motion.div>
      </main>
    </div>
  </MotionConfig>
);
