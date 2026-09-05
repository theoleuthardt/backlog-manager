"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

/**
 * Replaces tRPC's TRPCReactProvider now that data fetching goes through
 * plain REST calls (see lib/api/*.ts) instead of tRPC links - just a
 * React Query client for the whole client-rendered app. No SSR
 * hydration/dehydration config needed here (unlike the old
 * trpc/query-client.ts): nothing fetches through this client on the
 * server anymore, every data-fetching component is "use client".
 */
export function ApiProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 30 * 1000,
          },
        },
      }),
  );

  return (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
}
