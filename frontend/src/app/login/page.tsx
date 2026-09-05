"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "~/app/context/AuthContext";

export default function LoginPage() {
  const { user, login, logout, isLoading } = useAuth();
  const router = useRouter();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);
    try {
      await login(email, password);
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-black">
      <div className="container flex flex-col items-center justify-center gap-12 px-4 py-16 text-white">
        {isLoading ? (
          <p className="text-lg text-gray-300">Loading...</p>
        ) : !user ? (
          <>
            <h1 className="mb-6 text-5xl font-extrabold text-white text-shadow-md sm:text-[5rem]">
              Welcome Back
            </h1>
            <p className="mb-8 text-center text-lg text-gray-300">
              Log in to access your dashboard and manage your content.
            </p>
            <form
              onSubmit={handleSubmit}
              className="flex w-full max-w-sm flex-col gap-4"
            >
              {error && <p className="text-center text-red-400">{error}</p>}
              <input
                type="email"
                name="email"
                placeholder="Email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                autoComplete="email"
                className="w-full rounded-lg border border-gray-600 bg-black/20 px-4 py-3 text-white placeholder-gray-400 focus:border-blue-500 focus:outline-none"
              />
              <input
                type="password"
                name="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                autoComplete="current-password"
                className="w-full rounded-lg border border-gray-600 bg-black/20 px-4 py-3 text-white placeholder-gray-400 focus:border-blue-500 focus:outline-none"
              />
              <button
                type="submit"
                disabled={isSubmitting}
                className="rounded-full bg-blue-600 px-10 py-3 font-semibold text-white transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {isSubmitting ? "Logging in..." : "Login"}
              </button>
            </form>
          </>
        ) : (
          <div className="flex flex-col items-center gap-4">
            <p className="mb-6 text-2xl">You are logged in as {user.name}.</p>
            <p className="mb-4 text-center text-lg text-gray-300">
              If you want to logout, click the button below.
            </p>
            <button
              onClick={logout}
              className="rounded-full bg-white/10 px-10 py-3 font-semibold text-white transition hover:bg-white/20"
            >
              Sign out
            </button>
          </div>
        )}
      </div>
    </main>
  );
}
