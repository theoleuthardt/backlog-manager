"use client";
import React from "react";
import { useRouter } from "next/navigation";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";
import type { ExportCSVButtonProps } from "~/app/types";

export const ExportCSVButton = ({
  id = "export-csv-button",
  disabled = false,
  className = "",
  children,
  iconOnly = false,
}: ExportCSVButtonProps) => {
  const router = useRouter();

  const handleButtonClick = () => {
    router.push("/export-csv");
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
        <Image src="/csv_export.png" alt="export CSV" width={32} height={32} />
      ) : (
        children
      )}
    </Button>
  );
};
