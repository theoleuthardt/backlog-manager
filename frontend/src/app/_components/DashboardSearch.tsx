"use client";
import { useEffect, useRef } from "react";
import { SearchBar } from "components/SearchBar";
import { useDashboard } from "~/app/context/DashboardContext";

/**
 * Full-width search field for the middle of the navbar. Pressing "/"
 * or Ctrl/Cmd+K anywhere on the dashboard focuses it.
 */
export const DashboardSearch = () => {
  const { searchQuery, setSearchQuery } = useDashboard();
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      const isTyping =
        target instanceof HTMLInputElement ||
        target instanceof HTMLTextAreaElement ||
        target?.isContentEditable === true;
      const isShortcut =
        (event.key === "/" && !isTyping) ||
        (event.key.toLowerCase() === "k" && (event.metaKey || event.ctrlKey));
      if (!isShortcut) return;
      event.preventDefault();
      inputRef.current?.focus();
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  return (
    <SearchBar
      ref={inputRef as React.RefObject<HTMLInputElement>}
      useIcon
      value={searchQuery}
      placeholder="Search your backlog  ( / )"
      className="!mb-0 !max-w-none"
      onInput={(event) => setSearchQuery(event.currentTarget.value)}
      onClear={() => setSearchQuery("")}
    />
  );
};
