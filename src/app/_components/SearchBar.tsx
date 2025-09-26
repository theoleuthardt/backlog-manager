import React from "react";
import { Input } from "~/components/ui/input";
import Image from "next/image";

export const SearchBar = () => {
  return (
    <div className="relative mb-4 w-full max-w-sm">
      <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
        <Image src="/search.png" alt="Search" width={20} height={20} />
      </div>
      <Input
        type="search"
        placeholder="Suchen..."
        className="w-full border-2 border-blue-700 pl-10 focus:ring-2 focus:ring-blue-700"
      />
    </div>
  );
};
