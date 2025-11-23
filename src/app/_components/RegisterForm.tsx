"use client";

import { useState, type FormEvent } from "react";
import { api } from "~/trpc/react";
import { TRPCClientError } from "@trpc/client";
import { signIn } from "next-auth/react";
import Link from "next/link";

interface FormState {
  username: string;
  email: string;
  password: string;
  steamId: string;
}

export default function RegisterForm() {
  const [form, setForm] = useState<FormState>({
    username: "",
    email: "",
    password: "",
    steamId: "",
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const createUser = api.user.createUser.useMutation();

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm((f) => ({ ...f, [e.target.name]: e.target.value }));

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setErrors({});

    try {
      await createUser.mutateAsync({
        username: form.username,
        email: form.email,
        passwordHash: form.password,
        steamId: form.steamId || undefined,
      });

      await signIn(undefined, { callbackUrl: "/dashboard" });
    } catch (err: unknown) {
      // Sicherer Umgang mit TRPCClientError und Zod-Fehlern
      if (err instanceof TRPCClientError) {
        const fieldErrors: Record<string, string> = {};

        // Typ-Guard für err.data
        const data = err.data as
          | { zodError?: { fieldErrors?: Record<string, string[]> } }
          | undefined;

        const zodErrors = data?.zodError?.fieldErrors ?? {};

        for (const key in zodErrors) {
          const messages = zodErrors[key];
          if (messages?.length) {
            fieldErrors[key] = messages[0] ?? "Unknown error";
          }
        }

        setErrors(fieldErrors);
      } else if (err instanceof Error) {
        setErrors({ form: err.message });
      } else {
        setErrors({ form: "Unknown error occurred" });
      }
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

      {errors.form && (
        <div className="rounded bg-red-900/50 p-4 text-red-400">
          {errors.form}
        </div>
      )}

      {/* Username */}
      <div>
        <input
          type="text"
          name="username"
          placeholder="Username"
          value={form.username}
          onChange={handleChange}
          required
          className={`w-full rounded-lg border px-4 py-3 placeholder-gray-400 focus:outline-none ${
            errors.username
              ? "border-red-400 bg-red-900/20 text-red-200"
              : "border-gray-600 bg-black/20 text-white"
          }`}
        />
        {errors.username && (
          <p className="mt-1 text-sm text-red-400">{errors.username}</p>
        )}
      </div>

      {/* Email */}
      <div>
        <input
          type="email"
          name="email"
          placeholder="Email"
          value={form.email}
          onChange={handleChange}
          required
          className={`w-full rounded-lg border px-4 py-3 placeholder-gray-400 focus:outline-none ${
            errors.email
              ? "border-red-400 bg-red-900/20 text-red-200"
              : "border-gray-600 bg-black/20 text-white"
          }`}
        />
        {errors.email && (
          <p className="mt-1 text-sm text-red-400">{errors.email}</p>
        )}
      </div>

      {/* Password */}
      <div>
        <input
          type="password"
          name="password"
          placeholder="Password"
          value={form.password}
          onChange={handleChange}
          required
          className={`w-full rounded-lg border px-4 py-3 placeholder-gray-400 focus:outline-none ${
            errors.password
              ? "border-red-400 bg-red-900/20 text-red-200"
              : "border-gray-600 bg-black/20 text-white"
          }`}
        />
        {errors.password && (
          <p className="mt-1 text-sm text-red-400">{errors.password}</p>
        )}
      </div>

      {/* Steam ID */}
      <div>
        <input
          type="text"
          name="steamId"
          placeholder="Steam ID (optional)"
          value={form.steamId}
          onChange={handleChange}
          className="w-full rounded-lg border border-gray-600 bg-black/20 px-4 py-3 text-white placeholder-gray-400 focus:border-blue-500 focus:outline-none"
        />
      </div>

      <button
        type="submit"
        className="w-full rounded-full bg-green-600 px-6 py-3 font-semibold text-white transition hover:bg-green-700"
      >
        Register
      </button>

      <p className="text-center text-gray-400">
        Already have an account?{" "}
        <Link
          href="/login"
          className="text-blue-400 underline hover:text-blue-300"
        >
          Log in
        </Link>
      </p>

      <p className="text-center text-gray-400">
        Register with another provider?{" "}
        <button
          type="button"
          onClick={() => signIn(undefined, { callbackUrl: "/dashboard" })}
          className="text-blue-400 underline hover:text-blue-300"
        >
          Register here
        </button>
      </p>
    </form>
  );
}
