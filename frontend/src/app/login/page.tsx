"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { AuthCard } from "components/AuthCard";
import { Button } from "shadcn_components/ui/button";
import { Input } from "~/components/ui/input";
import { Label } from "~/components/ui/label";
import { Spinner } from "~/components/ui/spinner";
import { useAuth } from "~/app/context/AuthContext";

const APP_BUTTON =
  "border-2 border-white bg-black text-white hover:bg-white hover:text-black";

const FormError = ({ message }: { message: string | null }) =>
  message && (
    <p
      role="alert"
      className="border-destructive/50 bg-destructive/10 text-destructive rounded-lg border px-3 py-2 text-sm"
    >
      {message}
    </p>
  );

export default function LoginPage() {
  const { user, login, completeTwoFactorLogin, logout, isLoading } = useAuth();
  const router = useRouter();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [challengeToken, setChallengeToken] = useState<string | null>(null);
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);
    try {
      const outcome = await login(email, password);
      if (outcome.status === "requires_2fa") {
        setChallengeToken(outcome.challengeToken);
      } else {
        router.push("/dashboard");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleTwoFactorSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!challengeToken) return;
    setError(null);
    setIsSubmitting(true);
    try {
      await completeTwoFactorLogin(challengeToken, code);
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Invalid two-factor code");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleStartOver = () => {
    setChallengeToken(null);
    setCode("");
    setError(null);
  };

  if (isLoading) {
    return (
      <AuthCard title="Backlog Manager" description="Checking your session...">
        <div className="flex justify-center py-4">
          <Spinner className="text-primary h-8 w-8" />
        </div>
      </AuthCard>
    );
  }

  if (user) {
    return (
      <AuthCard
        title={`Hi, ${user.name}`}
        description="You are already signed in."
      >
        <div className="flex flex-col gap-3">
          <Button
            size="lg"
            variant="outline"
            className={APP_BUTTON}
            onClick={() => router.push("/dashboard")}
          >
            Go to Dashboard
          </Button>
          <Button
            size="lg"
            variant="outline"
            className={APP_BUTTON}
            onClick={logout}
          >
            Sign out
          </Button>
        </div>
      </AuthCard>
    );
  }

  if (challengeToken) {
    return (
      <AuthCard
        title="Two-factor authentication"
        description="Enter the 6-digit code from your authenticator app, or one of your backup codes."
      >
        <form onSubmit={handleTwoFactorSubmit} className="flex flex-col gap-4">
          <FormError message={error} />
          <div className="flex flex-col gap-2">
            <Label htmlFor="code">Verification code</Label>
            <Input
              id="code"
              type="text"
              name="code"
              placeholder="123456"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              required
              autoComplete="one-time-code"
              autoFocus
              className="h-11 text-center tracking-widest"
            />
          </div>
          <Button
            type="submit"
            size="lg"
            variant="outline"
            className={APP_BUTTON}
            disabled={isSubmitting}
          >
            {isSubmitting && <Spinner />}
            {isSubmitting ? "Verifying..." : "Verify"}
          </Button>
          <Button type="button" variant="link" onClick={handleStartOver}>
            Start over
          </Button>
        </form>
      </AuthCard>
    );
  }

  return (
    <AuthCard
      title="Welcome back!"
      description="Log in to access your dashboard and manage your backlog."
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <FormError message={error} />
        <div className="flex flex-col gap-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            type="email"
            name="email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoComplete="email"
            autoFocus
            className="h-11"
          />
        </div>
        <div className="flex flex-col gap-2">
          <Label htmlFor="password">Password</Label>
          <Input
            id="password"
            type="password"
            name="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            autoComplete="current-password"
            className="h-11"
          />
        </div>
        <Button
          type="submit"
          size="lg"
          variant="outline"
          className={APP_BUTTON}
          disabled={isSubmitting}
        >
          {isSubmitting && <Spinner />}
          {isSubmitting ? "Logging in..." : "Login"}
        </Button>
      </form>
    </AuthCard>
  );
}
