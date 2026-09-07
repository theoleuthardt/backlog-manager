"use client";

import Link from "next/link";
import { Button } from "shadcn_components/ui/button";
import { useAuth } from "~/app/context/AuthContext";

export function HeroCta() {
  const { user } = useAuth();
  const href = user ? "/dashboard" : "/login";
  const label = user ? "Go to Dashboard" : "Get Started today!";

  return (
    <Link href={href}>
      <Button
        variant="outline"
        className="border-black text-black transition-colors duration-300 hover:cursor-pointer hover:border-white hover:bg-transparent hover:text-white"
      >
        {label}
      </Button>
    </Link>
  );
}
