"use client";
import React from "react";
import { Input } from "~/components/ui/input";
import Image from "next/image";
import { X } from "lucide-react";
import type { SearchBarProps } from "~/app/types";

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
        placeholder={props.placeholder ?? "Search"}
        value={props.value}
        className={`w-full border-2 ${props.useIcon ? "pl-10" : ""} ${props.value && props.onClear ? "pr-10" : ""}`}
        onInput={(e) => {
          if (props.onInput) props.onInput(e as React.ChangeEvent<HTMLInputElement>);
        }}
      />
      {props.value && props.onClear && (
        <button
          onClick={props.onClear}
          className="absolute inset-y-0 right-0 flex items-center pr-3 text-red-500 transition-colors hover:text-red-700"
          type="button"
        >
          <X size={20} />
        </button>
      )}
    </div>
  );
};
