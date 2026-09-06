import { useQuery } from "@tanstack/react-query";
import { enrichedSearch } from "~/lib/api/games";

export function useGameSearch(searchTerm: string) {
  return useQuery({
    queryKey: ["game-search", searchTerm],
    queryFn: () => enrichedSearch(searchTerm),
    enabled: searchTerm.length > 0,
    refetchOnWindowFocus: false,
    staleTime: 1000 * 60 * 5,
    gcTime: 1000 * 60 * 10,
    retry: 3,
  });
}
