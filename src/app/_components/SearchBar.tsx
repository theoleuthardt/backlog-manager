"use client";
import React, { useState } from "react";
import { Input } from "~/components/ui/input";
import Image from "next/image";
import { X } from "lucide-react";
import { useDebounce } from "~/hooks/useDebounce";
import type { SearchBarProps } from "~/app/types";

interface SearchBarWithDebounceProps extends SearchBarProps {
  onDebouncedChange?: (value: string) => void;
  debounceDelay?: number;
}

export const SearchBar = (props: SearchBarWithDebounceProps) => {
  const [localValue, setLocalValue] = useState(props.value ?? "");
  const debouncedValue = useDebounce(localValue, props.debounceDelay ?? 300);
  const { onDebouncedChange } = props;

  React.useEffect(() => {
    if (onDebouncedChange) {
      onDebouncedChange(debouncedValue);
    }
  }, [debouncedValue, onDebouncedChange]);

  const handleInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    setLocalValue(e.currentTarget.value);
    if (props.onInput) props.onInput(e);
  };

  const handleClear = () => {
    setLocalValue("");
    if (props.onClear) props.onClear();
  };

  const displayValue = props.value ?? localValue;

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
        value={displayValue}
        className={`w-full border-2 ${props.useIcon ? "pl-10" : ""} ${displayValue && props.onClear ? "pr-10" : ""} [&::-webkit-search-cancel-button]:hidden`}
        onInput={handleInput}
      />
      {displayValue && props.onClear && (
        <button
          onClick={handleClear}
          className="absolute inset-y-0 right-0 flex items-center pr-3 text-red-500 transition-colors hover:text-red-700"
          type="button"
        >
          <X size={20} />
        </button>
      )}
    </div>
  );
};
