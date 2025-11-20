"use client";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";
import type { ExportCSVButtonProps } from "~/types";

export const ExportCSVButton = ({
  id = "export-csv-button",
  disabled = false,
  className = "",
  children,
  iconOnly = false,
}: ExportCSVButtonProps) => {
  return (
    <Button
      id={id}
      className={`border-0 bg-blue-700 font-bold text-white hover:bg-blue-800 hover:text-white ${className}`}
      variant="outline"
      disabled={disabled}
      onClick={() => {
        console.log("Export clicked!");
      }}
    >
      {iconOnly ? (
        <Image src="/csv_export.png" alt="export CSV" width={32} height={32} />
      ) : (
        children
      )}
    </Button>
  );
};
