import React from "react";
import { Input } from "~/components/ui/input";
import Image from "next/image";

export interface SearchBarProps {
  placeholder?: string;
  className?: string;
}

export const SearchBar = (props: SearchBarProps) => {
  return (
    <div className={`relative mb-4 w-full max-w-sm ${props.className}`}>
      <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
        <Image src="/search.png" alt="Search" width={20} height={20} />
      </div>
      <Input
        type="search"
        placeholder="Seach..."
        className="w-full border-2 pl-10"
      />
    </div>
  );
};
