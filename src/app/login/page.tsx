import Image from "next/image";
import { auth } from "~/server/auth";
import { HydrateClient } from "~/trpc/server";
import Link from "next/link";

export default async function LoginPage() {
  const session = await auth();

  return (
    <HydrateClient>
      <main className="flex min-h-screen flex-col items-center justify-center bg-black">
        <div className="container flex flex-col items-center justify-center gap-12 px-4 py-16 text-white">
          {!session?.user ? (
            <>
              <h1 className="mb-6 text-5xl font-extrabold text-white text-shadow-md sm:text-[5rem]">
                Welcome Back
              </h1>
              <p className="mb-8 text-center text-lg text-gray-300">
                Log in to access your dashboard and manage your content.
              </p>
              <div className="flex flex-col items-center gap-4">
                <Link
                  href="/api/auth/signin?callbackUrl=/dashboard"
                  className="rounded-full bg-blue-600 px-10 py-3 font-semibold text-white transition hover:bg-blue-700"
                >
                  Login
                </Link>
                <Link
                  href="/register"
                  className="rounded-full bg-green-600 px-10 py-3 font-semibold text-white transition hover:bg-green-700"
                >
                  Register
                </Link>
              </div>
            </>
          ) : (
            <div className="flex flex-col items-center gap-4">
              <p className="mb-6 text-2xl">
                You are logged in as {session.user.name ?? session.user.email}.
              </p>
              {session.user.image && (
                <Image
                  src={session.user.image}
                  width={48}
                  height={48}
                  alt={session.user.name ?? "Avatar"}
                  style={{ borderRadius: "50%" }}
                />
              )}
              <p className="mb-4 text-center text-lg text-gray-300">
                If you want to logout, click the button below.
              </p>
              <Link
                href="/api/auth/signout"
                className="rounded-full bg-white/10 px-10 py-3 font-semibold text-white transition hover:bg-white/20"
              >
                Sign out
              </Link>
            </div>
          )}
        </div>
      </main>
    </HydrateClient>
  );
}
