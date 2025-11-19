"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";

export default function SteamIdSetupPage() {
  const [steamId, setSteamId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const router = useRouter();

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSteamId(e.target.value);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    try {
      const res = await fetch("/api/user/update-steamid", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ steamId }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.message || "Updating Steam ID failed");
      }

      setSuccess(true);
    } catch (err: any) {
      setError(err.message);
    }
  };

  useEffect(() => {
    if (success) {
      router.push("/dashboard");
    }
  }, [success, router]);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-black px-4 text-white">
      <div className="container max-w-md">
        <h1 className="mb-6 text-4xl font-extrabold text-white">
          Steam ID Required
        </h1>
        <p className="mb-8 text-lg text-gray-300">
          It seems you have not yet provided your Steam ID. Please enter it
          here.
        </p>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          {error && <p className="text-red-400">{error}</p>}
          <input
            type="text"
            name="steamId"
            placeholder="Steam ID"
            value={steamId}
            onChange={handleChange}
            required
            className="w-full rounded-lg border border-gray-600 bg-black/20 px-4 py-3 text-white placeholder-gray-400 focus:border-blue-500 focus:outline-none"
          />
          <button
            type="submit"
            className="w-full rounded-full bg-green-600 px-6 py-3 font-semibold text-white transition hover:bg-green-700"
          >
            Save Steam ID
          </button>
        </form>
      </div>
    </main>
  );
}
