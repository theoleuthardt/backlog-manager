"use client";
import React, { type ReactNode } from "react";
import { useRef } from "react";
import { Button } from "shadcn_components/ui/button";

interface ImportCSVButtonProps {
  id: string;
  disabled: boolean;
  className?: string;
  children: ReactNode;
}

export const ImportCSVButton = (props: ImportCSVButtonProps) => {
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
        id={props.id}
        className={`relative mb-4 h-[2.5rem] w-[10rem] rounded-3xl border-0 bg-blue-700 p-4 font-bold text-white hover:bg-blue-800 hover:text-white ${props.className}`}
        variant="outline"
        disabled={props.disabled}
        onClick={handleButtonClick}
      >
        {props.children}
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
