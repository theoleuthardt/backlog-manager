"use client";
import type { ReactNode } from "react";
import { Button } from "shadcn_components/ui/button";

interface ExportCSVButtonProps {
  id: string;
  disabled: boolean;
  className?: string;
  children: ReactNode;
}

export const ExportCSVButton = (props: ExportCSVButtonProps) => {
  return (
    <Button
      id={props.id}
      className={`relative mb-4 h-[2.5rem] w-[10rem] rounded-3xl border-0 bg-blue-700 p-4 font-bold text-white hover:bg-blue-800 hover:text-white ${props.className}`}
      variant="outline"
      disabled={props.disabled}
      onClick={() => {
        console.log("Export clicked!");
      }}
    >
      {props.children}
    </Button>
  );
};
