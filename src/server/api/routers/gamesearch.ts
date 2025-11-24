import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "~/server/api/trpc";
import { SearchGame } from "~/server/integrations/howlongtobeat/howLongToBeat";

/**
 * Game Search Router
 *
 * Handles game search functionality using HowLongToBeat API
 */
export const gameSearchRouter = createTRPCRouter({
  /**
   * Search for games using HowLongToBeat API
   * @example
   * const results = await trpc.gameSearch.search.query({ searchTerm: "Zelda" })
   */
  search: publicProcedure
    .input(
      z.object({
        searchTerm: z.string().min(1, "Search term is required"),
      })
    )
    .query(async ({ input }) => {
      return await SearchGame(input.searchTerm);
    }),
});
