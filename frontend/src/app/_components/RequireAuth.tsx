"use client";

import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "~/app/context/AuthContext";
import { setupRedirect } from "~/lib/setupWizard";

/**
 * Replaces the old NextAuth-based proxy.ts route guard: the backend
 * authenticates via a Bearer token stored in localStorage (see
 * lib/api/token.ts), not a cookie, so a Next.js server-side
 * proxy/middleware can no longer inspect it - the check has to happen
 * client-side instead, after the initial "is this token still valid"
 * request resolves (see AuthContext).
 */
export function RequireAuth({ children }: { children: React.ReactNode }) {
  const { user, isLoading } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const redirectTo = user ? setupRedirect(user, pathname) : null;

  useEffect(() => {
    if (isLoading) return;
    if (!user) {
      router.replace("/login");
    } else if (redirectTo) {
      router.replace(redirectTo);
    }
  }, [isLoading, user, redirectTo, router]);

  if (isLoading || !user || redirectTo) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-black text-white">
        <p>Loading...</p>
      </div>
    );
  }

  return <>{children}</>;
}
