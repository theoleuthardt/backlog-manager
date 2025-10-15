"use client";
import React from "react";
import { Input } from "~/components/ui/input";
import Image from "next/image";

export interface SearchBarProps {
  placeholder?: string;
  className?: string;
  onInput?: Function;
  ref?: React.RefObject<HTMLInputElement>;
}

export const SearchBar = (props: SearchBarProps) => {
  return (
    <div className={`relative mb-4 w-full max-w-sm ${props.className}`}>
      <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
        <Image src="/search.png" alt="Search" width={20} height={20} />
      </div>
      <Input
        ref={props.ref}
        type="search"
        placeholder="Seach..."
        className="w-full border-2 pl-10"
        onInput={() => {
          if (props.onInput) props.onInput();
        }}
      />
    </div>
  );
};
