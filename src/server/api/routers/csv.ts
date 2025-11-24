import { z } from "zod";

import {
  createTRPCRouter,
  protectedProcedure,
} from "~/server/api/trpc";
import { parseCSVContent, importBacklogEntriesFromCSV, getImportProgress, clearImportProgress, type ColumnConfig } from "~/server/csv/parseCSV";
import * as backlogEntryService from "~/server/services/backlogEntryService";
import pool from "~/server/db/index";

export const csvRouter = createTRPCRouter({
  parse: protectedProcedure
    .input(z.object({ content: z.string() }))
    .mutation(async ({ input }) => {
      try {
        const records = await parseCSVContent(input.content);
        return {
          success: true,
          data: records,
          error: null,
        };
      } catch (error) {
        return {
          success: false,
          data: null,
          error: error instanceof Error ? error.message : "Unknown error occurred",
        };
      }
    }),

  importEntries: protectedProcedure
    .input(z.object({
      content: z.string(),
      titleColumn: z.string(),
      genreColumn: z.string(),
      platformColumn: z.string(),
      statusColumn: z.string(),
      sessionId: z.string().optional(),
    }))
    .mutation(async ({ ctx, input }) => {
      try {
        const userId = parseInt(ctx.session?.user?.id ?? "0");
        const records = await parseCSVContent(input.content);

        const config: ColumnConfig = {
          titleColumn: input.titleColumn,
          genreColumn: input.genreColumn,
          platformColumn: input.platformColumn,
          statusColumn: input.statusColumn,
        };

        const results = await importBacklogEntriesFromCSV(pool, userId, records, config, input.sessionId);
        return {
          success: true,
          data: results,
          error: null,
        };
      } catch (error) {
        return {
          success: false,
          data: null,
          error: error instanceof Error ? error.message : "Unknown error occurred",
        };
      }
    }),

  getProgress: protectedProcedure
    .input(z.object({
      sessionId: z.string(),
    }))
    .query(async ({ input }) => {
      const processed = getImportProgress(input.sessionId);
      return {
        processed,
      };
    }),

  createMissingGameEntry: protectedProcedure
    .input(z.object({
      missingGame: z.object({
        title: z.string(),
        genre: z.string(),
        platform: z.string(),
        status: z.string(),
      }),
      gameData: z.object({
        hltbId: z.number(),
        title: z.string(),
        imageUrl: z.string(),
        mainStory: z.number(),
        mainStoryWithExtras: z.number(),
        completionist: z.number(),
      }),
    }))
    .mutation(async ({ ctx, input }) => {
      try {
        const userId = parseInt(ctx.session?.user?.id ?? "0");

        const entryParams = {
          userId,
          title: input.gameData.title,
          genre: input.missingGame.genre,
          platform: input.missingGame.platform,
          status: "Not Started",  //TODO update when status is no enum anymore :)
          owned: true,
          interest: 5,
          imageLink: input.gameData.imageUrl,
          mainTime: input.gameData.mainStory,
          mainPlusExtraTime: input.gameData.mainStoryWithExtras,
          completionTime: input.gameData.completionist,
        };

        const createdEntry = await backlogEntryService.createBacklogEntry(pool, entryParams);

        return {
          success: true,
          data: createdEntry,
          error: null,
        };
      } catch (error) {
        return {
          success: false,
          data: null,
          error: error instanceof Error ? error.message : "Unknown error occurred",
        };
      }
    }),
});