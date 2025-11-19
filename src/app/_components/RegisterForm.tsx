"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";

export default function RegisterForm() {
  const [form, setForm] = useState({
    username: "",
    email: "",
    password: "",
    steamId: "",
  });
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const router = useRouter();

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    try {
      const res = await fetch("/api/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.message || "Registration failed");
      }

      setSuccess(true);
    } catch (err: any) {
      setError(err.message);
    }
  };

  useEffect(() => {
    if (success) {
      router.push("/api/auth/signin?callbackUrl=/dashboard");
    }
  }, [success, router]);

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
