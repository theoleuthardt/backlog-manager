"use client";
import React from "react";
import { useNavigate } from "react-router";
import { Button } from "shadcn_components/ui/button";
import type { ImportCSVButtonProps } from "~/app/types";

export const ImportCSVButton = ({
  id = "import-csv-button",
  disabled = false,
  className = "",
  children,
  iconOnly = false,
}: ImportCSVButtonProps) => {
  const navigate = useNavigate();

  const handleButtonClick = () => {
    void navigate("/import-csv");
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
        <img
          src="/csv_import.png"
          alt="import CSV"
          width={32}
          height={32}
          className="themed-icon"
        />
      ) : (
        children
      )}
    </Button>
  );
};
