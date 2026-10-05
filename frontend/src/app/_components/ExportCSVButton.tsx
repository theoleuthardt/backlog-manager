"use client";
import React from "react";
import { useNavigate } from "react-router";
import { Button } from "shadcn_components/ui/button";
import type { ExportCSVButtonProps } from "~/app/types";

export const ExportCSVButton = ({
  id = "export-csv-button",
  disabled = false,
  className = "",
  children,
  iconOnly = false,
}: ExportCSVButtonProps) => {
  const navigate = useNavigate();

  const handleButtonClick = () => {
    void navigate("/export-csv");
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
          src="/csv_export.png"
          alt="export CSV"
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
