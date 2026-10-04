"use client";

import React, { createContext, useContext } from "react";

const BacklogScopeContext = createContext<number | undefined>(undefined);

/**
 * Points every backlog hook below it at a shared space instead of the
 * personal backlog, so the dashboard components work unchanged on both.
 * Outside a provider the scope is the personal backlog.
 */
export function BacklogScopeProvider({
  spaceId,
  children,
}: {
  spaceId: number;
  children: React.ReactNode;
}) {
  return (
    <BacklogScopeContext.Provider value={spaceId}>
      {children}
    </BacklogScopeContext.Provider>
  );
}

export function useBacklogSpaceId(): number | undefined {
  return useContext(BacklogScopeContext);
}
