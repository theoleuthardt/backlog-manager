import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "~/server/api/trpc";
import {
  generateIGDBToken,
  searchGameOnIGDB,
  getGameOnIGDB,
  getPlatformOnIGDB,
  getCoverOnIGDB,
  getGenreOnIGDB,
  getGameTimeToBeatOnIGDB,
} from "~/server/integrations/igdb/igdb";
import type { EnrichedResult } from "~/server/integrations/types";

let cachedToken: { accessToken: string; expiresAt: number } | null = null;
const genreCache = new Map<number, string>();
const platformCache = new Map<number, string>();

/**
 * Gets a valid IGDB access token, using cached token if available
 */
async function getValidToken(): Promise<string> {
  const clientId = process.env.IGDB_CLIENT_ID;
  const clientSecret = process.env.IGDB_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new Error(
      "IGDB credentials not configured. Please set IGDB_CLIENT_ID and IGDB_CLIENT_SECRET environment variables.",
    );
  }

  if (cachedToken && cachedToken.expiresAt > Date.now()) {
    return cachedToken.accessToken;
  }

  const tokenResponse = await generateIGDBToken(clientId, clientSecret);

  if (!tokenResponse.access_token) {
    throw new Error("Failed to generate IGDB access token");
  }

  // Cache the token (expires_in is in seconds, convert to milliseconds)
  const expiresAt = Date.now() + (tokenResponse.expires_in - 300) * 1000;
  cachedToken = {
    accessToken: tokenResponse.access_token,
    expiresAt,
  };

  return tokenResponse.access_token;
}

/**
 * Fetch genre with caching
 */
async function getCachedGenre(
  genreId: number,
  clientId: string,
  accessToken: string,
): Promise<string | null> {
  if (genreCache.has(genreId)) {
    return genreCache.get(genreId)!;
  }

  try {
    const genreData = await getGenreOnIGDB(genreId, clientId, accessToken);
    const name = genreData[0]?.name;
    if (name) {
      genreCache.set(genreId, name);
      return name;
    }
  } catch (error) {
    console.error(`Failed to fetch genre ${genreId}:`, error);
  }
  return null;
}

/**
 * Fetch platform with caching
 */
async function getCachedPlatform(
  platformId: number,
  clientId: string,
  accessToken: string,
): Promise<string | null> {
  if (platformCache.has(platformId)) {
    return platformCache.get(platformId)!;
  }

  try {
    const platformData = await getPlatformOnIGDB(
      platformId,
      clientId,
      accessToken,
    );
    const name = platformData[0]?.name;
    if (name) {
      platformCache.set(platformId, name);
      return name;
    }
  } catch (error) {
    console.error(`Failed to fetch platform ${platformId}:`, error);
  }
  return null;
}

/**
 * Process games with controlled concurrency to avoid rate limiting
 * Adds a delay between batches to respect API rate limits
 */
async function processInBatches<T, R>(
  items: T[],
  batchSize: number,
  processor: (item: T) => Promise<R>,
  delayBetweenBatchesMs = 1000,
): Promise<R[]> {
  const results: R[] = [];
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchResults = await Promise.all(batch.map(processor));
    results.push(...batchResults);

    if (i + batchSize < items.length) {
      await new Promise((resolve) =>
        setTimeout(resolve, delayBetweenBatchesMs),
      );
    }
  }
  return results;
}

/**
 * IGDB Router
 *
 * Handles game data fetching from IGDB API
 */
export const IGDBRouter = createTRPCRouter({
  /**
   * Search for games on IGDB
   * @example
   * const results = await trpc.igdb.searchGame.query({ searchTerm: "Zelda" })
   */
  searchGame: publicProcedure
    .input(
      z.object({
        searchTerm: z.string().min(1, "Search term is required"),
      }),
    )
    .query(async ({ input }) => {
      const clientId = process.env.IGDB_CLIENT_ID;
      if (!clientId) {
        throw new Error("IGDB_CLIENT_ID not configured");
      }

      const accessToken = await getValidToken();
      return await searchGameOnIGDB(input.searchTerm, clientId, accessToken);
    }),

  /**
   * Get detailed game information by ID
   * @example
   * const game = await trpc.igdb.getGame.query({ gameId: "141503" })
   */
  getGame: publicProcedure
    .input(
      z.object({
        gameId: z.string().min(1, "Game ID is required"),
      }),
    )
    .query(async ({ input }) => {
      const clientId = process.env.IGDB_CLIENT_ID;
      if (!clientId) {
        throw new Error("IGDB_CLIENT_ID not configured");
      }

      const accessToken = await getValidToken();
      return await getGameOnIGDB(input.gameId, clientId, accessToken);
    }),

  /**
   * Get platform information by ID
   * @example
   * const platform = await trpc.igdb.getPlatform.query({ platformId: 169 })
   */
  getPlatform: publicProcedure
    .input(
      z.object({
        platformId: z.number().int().positive("Platform ID must be positive"),
      }),
    )
    .query(async ({ input }) => {
      const clientId = process.env.IGDB_CLIENT_ID;
      if (!clientId) {
        throw new Error("IGDB_CLIENT_ID not configured");
      }

      const accessToken = await getValidToken();
      return await getPlatformOnIGDB(input.platformId, clientId, accessToken);
    }),

  /**
   * Get cover image information by ID
   * @example
   * const cover = await trpc.igdb.getCover.query({ coverId: 171645 })
   */
  getCover: publicProcedure
    .input(
      z.object({
        coverId: z.number().int().positive("Cover ID must be positive"),
      }),
    )
    .query(async ({ input }) => {
      const clientId = process.env.IGDB_CLIENT_ID;
      if (!clientId) {
        throw new Error("IGDB_CLIENT_ID not configured");
      }

      const accessToken = await getValidToken();
      return await getCoverOnIGDB(input.coverId, clientId, accessToken);
    }),

  /**
   * Get genre information by ID
   * @example
   * const genre = await trpc.igdb.getGenre.query({ genreId: 10 })
   */
  getGenre: publicProcedure
    .input(
      z.object({
        genreId: z.number().int().positive("Genre ID must be positive"),
      }),
    )
    .query(async ({ input }) => {
      const clientId = process.env.IGDB_CLIENT_ID;
      if (!clientId) {
        throw new Error("IGDB_CLIENT_ID not configured");
      }

      const accessToken = await getValidToken();
      return await getGenreOnIGDB(input.genreId, clientId, accessToken);
    }),

  /**
   * Get game time to beat information by game ID
   * @example
   * const timeToBeat = await trpc.igdb.getGameTimeToBeat.query({ gameId: 141503 })
   */
  getGameTimeToBeat: publicProcedure
    .input(
      z.object({
        gameId: z.number().int().positive("Game ID must be positive"),
      }),
    )
    .query(async ({ input }) => {
      const clientId = process.env.IGDB_CLIENT_ID;
      if (!clientId) {
        throw new Error("IGDB_CLIENT_ID not configured");
      }

      const accessToken = await getValidToken();
      return await getGameTimeToBeatOnIGDB(input.gameId, clientId, accessToken);
    }),

  /**
   * Enriched search endpoint that returns data compatible with frontend expectations
   * Searches IGDB and enriches results with cover images and time-to-beat data
   * @example
   * const results = await trpc.igdb.search.query({ searchTerm: "Zelda" })
   */
  search: publicProcedure
    .input(
      z.object({
        searchTerm: z.string().min(1, "Search term is required"),
      }),
    )
    .query(async ({ input }) => {
      const clientId = process.env.IGDB_CLIENT_ID;
      if (!clientId) {
        throw new Error("IGDB_CLIENT_ID not configured");
      }

      const accessToken = await getValidToken();

      const searchResults = await searchGameOnIGDB(
        input.searchTerm,
        clientId,
        accessToken,
      );

      const gamesToProcess = searchResults.slice(0, 8);
      const enrichedResults = await processInBatches(
        gamesToProcess,
        1,
        async (searchResult) => {
          try {
            const gameId =
              searchResult.game?.toString() ?? searchResult.id.toString();
            const gameData = await getGameOnIGDB(gameId, clientId, accessToken);
            const game = gameData[0];

            if (!game) {
              return null;
            }

            let imageUrl: string | null = null;
            if (game.cover) {
              try {
                const coverData = await getCoverOnIGDB(
                  game.cover,
                  clientId,
                  accessToken,
                );
                const cover = coverData[0];
                if (cover?.image_id) {
                  imageUrl = `https://images.igdb.com/igdb/image/upload/t_cover_big/${cover.image_id}.jpg`;
                }
              } catch (error) {
                console.error(
                  `Failed to fetch cover for game ${game.id}:`,
                  error,
                );
              }
            }

            let genres: string[] = [];
            if (game.genres && Array.isArray(game.genres)) {
              try {
                const genreNames = await Promise.all(
                  game.genres.map((genreId: number) =>
                    getCachedGenre(genreId, clientId, accessToken),
                  ),
                );
                genres = genreNames.filter(
                  (name): name is string => name !== null,
                );
              } catch (error) {
                console.error(
                  `Failed to fetch genres for game ${game.id}:`,
                  error,
                );
              }
            }

            let platforms: string[] = [];
            if (game.platforms && Array.isArray(game.platforms)) {
              try {
                const platformNames = await Promise.all(
                  game.platforms.map((platformId: number) =>
                    getCachedPlatform(platformId, clientId, accessToken),
                  ),
                );
                platforms = platformNames.filter(
                  (name): name is string => name !== null,
                );
              } catch (error) {
                console.error(
                  `Failed to fetch platforms for game ${game.id}:`,
                  error,
                );
              }
            }

            let mainStory = 0;
            let mainStoryWithExtras = 0;
            let completionist = 0;

            try {
              const timeToBeatData = await getGameTimeToBeatOnIGDB(
                game.id,
                clientId,
                accessToken,
              );
              const timeToBeat = timeToBeatData[0];
              if (timeToBeat) {
                mainStory = timeToBeat.hastily
                  ? Math.round((timeToBeat.hastily / 3600) * 10) / 10
                  : 0;
                mainStoryWithExtras = timeToBeat.normally
                  ? Math.round((timeToBeat.normally / 3600) * 10) / 10
                  : 0;
                completionist = timeToBeat.completely
                  ? Math.round((timeToBeat.completely / 3600) * 10) / 10
                  : 0;
              }
            } catch {
              console.log(`No time to beat data for game ${game.id}`);
            }

            return {
              id: game.id,
              hltbId: game.id,
              title: game.name ?? "Unknown Game",
              imageUrl,
              steamAppId: null,
              genres,
              platforms,
              mainStory,
              mainStoryWithExtras,
              completionist,
            } as EnrichedResult;
          } catch (error) {
            console.error("Error enriching game data:", error);
            return null;
          }
        },
      );

      return enrichedResults.filter(
        (result): result is NonNullable<EnrichedResult> => result !== null,
      );
    }),
});
