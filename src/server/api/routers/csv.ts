import { z } from "zod";

import {
  createTRPCRouter,
  protectedProcedure,
} from "~/server/api/trpc";
import { parseCSVContent, importBacklogEntriesFromCSV, type ColumnConfig } from "~/server/csv/parseCSV";
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
    }))
    .mutation(async ({ ctx, input }) => {
      try {
        const userId = parseInt(ctx.session.user.id || "0");
        const records = await parseCSVContent(input.content);

        const config: ColumnConfig = {
          titleColumn: input.titleColumn,
          genreColumn: input.genreColumn,
          platformColumn: input.platformColumn,
          statusColumn: input.statusColumn,
        };

        const results = await importBacklogEntriesFromCSV(pool, userId, records, config);
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
});