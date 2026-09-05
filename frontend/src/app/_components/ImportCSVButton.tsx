"use client";
import React from "react";
import { useRouter } from "next/navigation";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";
import type { ImportCSVButtonProps } from "~/app/types";

export const ImportCSVButton = ({
  id = "import-csv-button",
  disabled = false,
  className = "",
  children,
  iconOnly = false,
}: ImportCSVButtonProps) => {
  const router = useRouter();

  const handleButtonClick = () => {
    router.push("/import-csv");
  };

  return (
    <Button
      id={id}
      className={`border-0 font-bold text-white ${className}`}
      variant="outline"
      disabled={disabled}
      onClick={handleButtonClick}
    >
      {iconOnly ? (
        <Image
          src="/csv_import.png"
          alt="import CSV"
          width={32}
          height={32}
        />
      ) : (
        children
      )}
    </Button>
  );
};
