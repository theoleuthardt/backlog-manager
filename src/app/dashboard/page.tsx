// src/app/dashboard/page.tsx
import Image from "next/image";
import { auth } from "~/server/auth";
import { HydrateClient } from "~/trpc/server";

export default async function DashboardPage() {
  const session = await auth();

  return (
    <HydrateClient>
      <main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-black to-blue-900 text-white">
        {!session?.user ? (
          <p className="text-xl text-gray-300">
            You are not logged in. Please{" "}
            <a
              href="/login"
              className="text-blue-400 underline hover:text-blue-300"
            >
              log in
            </a>
            .
          </p>
        ) : (
          <div className="flex flex-col items-center gap-6">
            <h1 className="text-4xl font-bold">Dashboard</h1>
            <p className="text-2xl">
              Logged in as{" "}
              <span className="font-semibold">{session.user.name}</span>
            </p>
            {session.user.image && (
              <Image
                src={session.user.image}
                width={96}
                height={96}
                alt={session.user.name ?? "User Avatar"}
                className="rounded-full border-2 border-white/20 shadow-lg"
              />
            )}
          </div>
        )}
      </main>
    </HydrateClient>
  );
}
