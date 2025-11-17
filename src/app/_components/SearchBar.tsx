"use client";
import React from "react";
import { Input } from "~/components/ui/input";
import Image from "next/image";

export interface SearchBarProps {
  placeholder?: string;
  className?: string;
  onInput?: Function;
  ref?: React.RefObject<HTMLInputElement>;
  useIcon: boolean;
}

export const SearchBar = (props: SearchBarProps) => {
  return (
    <div className={`relative mb-4 w-full max-w-sm ${props.className}`}>
      {props.useIcon && (
        <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
          <Image src="/search.png" alt="Search" width={20} height={20} />
        </div>
      )}
      <Input
        ref={props.ref}
        type="search"
        placeholder={props.placeholder || "Search"}
        className={`w-full border-2 ${props.useIcon ? "pl-10" : ""}`}
        onInput={(e) => {
          if (props.onInput) props.onInput(e);
        }}
      />
    </div>
  );
};
