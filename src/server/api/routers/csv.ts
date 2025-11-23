import { z } from "zod";

import {
  createTRPCRouter,
  publicProcedure,
} from "~/server/api/trpc";
import { parseCSVContent } from "~/server/integrations/csv/parseCSV";

export const csvRouter = createTRPCRouter({
  parse: publicProcedure
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
});