"use client";

import React, { createContext, useContext, useMemo, useState } from "react";

interface DashboardContextType {
  searchQuery: string;
  setSearchQuery: (query: string) => void;
}

const DashboardContext = createContext<DashboardContextType | null>(null);

/**
 * Holds the dashboard search text so the search bar in the navbar and
 * the entry grid, which are siblings in the page tree, share it.
 */
export function DashboardProvider({ children }: { children: React.ReactNode }) {
  const [searchQuery, setSearchQuery] = useState("");
  const value = useMemo(() => ({ searchQuery, setSearchQuery }), [searchQuery]);
  return (
    <DashboardContext.Provider value={value}>
      {children}
    </DashboardContext.Provider>
  );
}

export function useDashboard(): DashboardContextType {
  const context = useContext(DashboardContext);
  if (!context) {
    throw new Error("useDashboard must be used within a DashboardProvider");
  }
  return context;
}
