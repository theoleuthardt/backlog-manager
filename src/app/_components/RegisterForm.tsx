"use client";

import { useState, useEffect, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { api } from "~/trpc/react";

export default function RegisterForm() {
  const [form, setForm] = useState({
    username: "",
    email: "",
    password: "",
    steamId: "",
  });
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const register = api.user.register.useMutation();

  const handleChange = (e: any) =>
    setForm((f) => ({ ...f, [e.target.name]: e.target.value }));

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    try {
      await register.mutateAsync({
        username: form.username,
        email: form.email,
        password: form.password,
        steamId: form.steamId || undefined,
      });

      router.push("/api/auth/signin?callbackUrl=/dashboard");
    } catch (err: any) {
      setError(err.message || "Failed to register user");
    }
  };
  return (
    <form
      onSubmit={handleSubmit}
      className="flex w-full max-w-md flex-col gap-4"
    >
      <p className="mb-8 text-center text-lg text-gray-300">
        Fill in your details to create a new account.
      </p>
      {error && <p className="text-red-400">{error}</p>}

      <input
        type="text"
        name="username"
        placeholder="Username"
        value={form.username}
        onChange={handleChange}
        required
        className="w-full rounded-lg border border-gray-600 bg-black/20 px-4 py-3 text-white placeholder-gray-400 focus:border-blue-500 focus:outline-none"
      />

      <input
        type="email"
        name="email"
        placeholder="Email"
        value={form.email}
        onChange={handleChange}
        required
        className="w-full rounded-lg border border-gray-600 bg-black/20 px-4 py-3 text-white placeholder-gray-400 focus:border-blue-500 focus:outline-none"
      />

      <input
        type="password"
        name="password"
        placeholder="Password"
        value={form.password}
        onChange={handleChange}
        required
        className="w-full rounded-lg border border-gray-600 bg-black/20 px-4 py-3 text-white placeholder-gray-400 focus:border-blue-500 focus:outline-none"
      />

      <input
        type="text"
        name="steamId"
        placeholder="Steam ID (optional)"
        value={form.steamId}
        onChange={handleChange}
        className="w-full rounded-lg border border-gray-600 bg-black/20 px-4 py-3 text-white placeholder-gray-400 focus:border-blue-500 focus:outline-none"
      />

      <button
        type="submit"
        className="w-full rounded-full bg-green-600 px-6 py-3 font-semibold text-white transition hover:bg-green-700"
      >
        Register
      </button>

      <p className="text-center text-gray-400">
        Already have an account?{" "}
        <a
          href="/login"
          className="text-blue-400 underline hover:text-blue-300"
        >
          Log in
        </a>
      </p>
      <p className="text-center text-gray-400">
        Register with another provider?{" "}
        <a
          href="/api/auth/signin?callbackUrl=/dashboard"
          className="text-blue-400 underline hover:text-blue-300"
        >
          Register here
        </a>
      </p>
    </form>
  );
}
