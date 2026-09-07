import { useQuery } from "@tanstack/react-query";
import {
  enrichedSearch,
  getSteamAppId,
  getSteamGridDbCovers,
} from "~/lib/api/games";

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

export function useSteamAppId(title: string) {
  return useQuery({
    queryKey: ["steam-app-id", title],
    queryFn: () => getSteamAppId(title),
    enabled: title.length > 0,
    refetchOnWindowFocus: false,
    staleTime: 1000 * 60 * 60,
    gcTime: 1000 * 60 * 60,
    retry: 1,
  });
}

export function useSteamGridDbCovers(steamAppId: number | undefined, enabled: boolean) {
  return useQuery({
    queryKey: ["steamgriddb-covers", steamAppId],
    queryFn: () => getSteamGridDbCovers(steamAppId!),
    enabled: enabled && steamAppId !== undefined,
    refetchOnWindowFocus: false,
    staleTime: 1000 * 60 * 60,
    gcTime: 1000 * 60 * 60,
    retry: 1,
  });
}
