"use client";

import Link from "next/link";
import { Button } from "shadcn_components/ui/button";
import { useAuth } from "~/app/context/AuthContext";

export function HeroCta() {
  const { user, isLoading } = useAuth();

  if (isLoading) {
    return (
      <Button
        disabled
        variant="outline"
        className="border-black text-black transition-colors duration-300 hover:cursor-pointer hover:border-white hover:bg-transparent hover:text-white"
      >
        Get Started today!
      </Button>
    );
  }

  const href = user ? "/dashboard" : "/login";
  const label = user ? "Go to Dashboard" : "Get Started today!";

  return (
    <Button
      asChild
      variant="outline"
      className="border-black text-black transition-colors duration-300 hover:cursor-pointer hover:border-white hover:bg-transparent hover:text-white"
    >
      <Link href={href}>{label}</Link>
    </Button>
  );
}
