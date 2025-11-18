"use client";
import React, { type ReactNode } from "react";
import { useRef } from "react";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";

interface ImportCSVButtonProps {
  id?: string;
  disabled?: boolean;
  className?: string;
  children?: ReactNode;
  iconOnly?: boolean;
}

export const ImportCSVButton = ({
  id = "import-csv-button",
  disabled = false,
  className = "",
  children,
  iconOnly = false,
}: ImportCSVButtonProps) => {
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleButtonClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      console.log("Selected file:", file);
    }
  };

  return (
    <>
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
      <input
        ref={fileInputRef}
        type="file"
        accept=".csv"
        className="hidden"
        onChange={handleFileChange}
      />
    </>
  );
};
