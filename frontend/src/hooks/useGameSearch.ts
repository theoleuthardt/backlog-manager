import { useQuery } from "@tanstack/react-query";
import {
  enrichedSearch,
  getGamePrice,
  getKeyShopPrices,
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

export function useSteamGridDbCovers(
  steamAppId: number | undefined,
  enabled: boolean,
) {
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

export function useGamePrice(steamAppId: number | undefined, enabled = true) {
  return useQuery({
    queryKey: ["game-price", steamAppId],
    queryFn: () => getGamePrice(steamAppId!),
    enabled: enabled && steamAppId !== undefined,
    refetchOnWindowFocus: false,
    staleTime: 1000 * 60 * 60,
    gcTime: 1000 * 60 * 60,
    retry: 1,
  });
}

export function useKeyShopPrices(title: string, enabled = true) {
  return useQuery({
    queryKey: ["key-shop-prices", title],
    queryFn: () => getKeyShopPrices(title),
    enabled: enabled && title.length > 0,
    refetchOnWindowFocus: false,
    staleTime: 1000 * 60 * 60,
    gcTime: 1000 * 60 * 60,
    retry: 1,
  });
}
