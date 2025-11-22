import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "~/server/api/trpc";
import pool from "~/server/db/index";
import * as backlogEntryService from "~/server/services/backlogEntryService";
import * as categoryService from "~/server/services/categoryService";

// ============================================================================
// TODO: TEMPORARY FOR TESTING - Remove when merging auth branch
//
// INSTRUCTIONS FOR REVERTING WHEN MERGING AUTH:
// 1. Change all 'publicProcedure' back to 'protectedProcedure'
// 2. Remove ' || String(TEST_USER_ID)' from all userId lines
// 3. Remove this TEST_USER_ID constant
// 4. Remove all "TODO: Change back to protectedProcedure after auth merge" comments
//
// PREREQUISITES FOR TESTING:
// - Ensure a user with ID=1 exists in your database
// - If not, run: INSERT INTO "Users" (username, email) VALUES ('test', 'test@test.com');
// ============================================================================
const TEST_USER_ID = 1;

/**
 * Backlog Entry Router
 *
 * TEMP: Using publicProcedure for testing. Will use protectedProcedure after auth merge.
 * The userId is obtained from the authenticated session (or TEST_USER_ID for now).
 */
export const backlogRouter = createTRPCRouter({
  /**
   * CREATE PROCEDURES
   */

  /**
   * Create a new backlog entry
   * @example
   * await trpc.backlog.createEntry.mutate({
   *   title: "The Legend of Zelda",
   *   genre: "Action-Adventure",
   *   platform: "Nintendo Switch",
   *   status: "Backlog",
   *   owned: true,
   *   interest: 8,
   *   imageLink: "https://..."
   * })
   */
  createEntry: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(
      z.object({
        title: z.string().min(1, "Title is required"),
        genre: z.string().min(1, "Genre is required"),
        platform: z.string().min(1, "Platform is required"),
        status: z.enum(["Backlog", "Playing", "Completed", "Dropped"]),
        owned: z.boolean(),
        interest: z.number().min(0).max(10),
        releaseDate: z.date().optional(),
        imageLink: z.string().optional(), // Allow any string, not just URLs
        mainTime: z.number().positive().optional(),
        mainPlusExtraTime: z.number().positive().optional(),
        completionTime: z.number().positive().optional(),
        reviewStars: z.number().min(0).max(5).optional(),
        review: z.string().optional(),
        note: z.string().optional(),
      })
    )
    .mutation(async ({ ctx, input }) => {
      // TODO: Remove fallback after auth merge
      const userId = parseInt(ctx.session?.user?.id ?? String(TEST_USER_ID));

      // Map frontend status values to database values
      const statusMap: Record<string, string> = {
        "Backlog": "Not Started",
        "Playing": "In Progress",
        "Completed": "Completed",
        "Dropped": "Dropped",
      };

      const mappedStatus = statusMap[input.status] ?? "Not Started";

      return await backlogEntryService.createBacklogEntry(pool, {
        userId,
        ...input,
        status: mappedStatus,
        // Round reviewStars to integer for database compatibility
        reviewStars: input.reviewStars ? Math.round(input.reviewStars) : undefined,
      });
    }),

  /**
   * Create a new category
   * @example
   * await trpc.backlog.createCategory.mutate({
   *   categoryName: "Platformers",
   *   color: "#FF0000",
   *   description: "Platformer games"
   * })
   */
  createCategory: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(
      z.object({
        categoryName: z.string().min(1, "Category name is required"),
        color: z
          .string()
          .regex(/^#[0-9A-F]{6}$/i, "Invalid color format")
          .optional(),
        description: z.string().optional(),
      })
    )
    .mutation(async ({ ctx, input }) => {
      const userId = parseInt(ctx.session?.user?.id ?? String(TEST_USER_ID));
      return await categoryService.createCategory(pool, {
        userId,
        ...input,
      });
    }),

  /**
   * Add a category to a backlog entry
   * @example
   * await trpc.backlog.addCategoryToEntry.mutate({
   *   categoryId: 1,
   *   backlogEntryId: 5
   * })
   */
  addCategoryToEntry: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(
      z.object({
        categoryId: z.number().positive(),
        backlogEntryId: z.number().positive(),
      })
    )
    .mutation(async ({ input }) => {
      return await backlogEntryService.addCategoryToBacklogEntry(pool, input);
    }),

  /**
   * READ PROCEDURES
   */

  /**
   * Get all backlog entries for the current user
   * @example
   * const entries = await trpc.backlog.getEntries.query()
   */
  getEntries: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .query(async ({ ctx }) => {
      const userId = parseInt(ctx.session?.user?.id ?? String(TEST_USER_ID));
      return await backlogEntryService.getBacklogEntriesByUser(pool, userId);
    }),

  /**
   * Get a specific backlog entry by ID
   * @example
   * const entry = await trpc.backlog.getEntryById.query({ backlogEntryId: 1 })
   */
  getEntryById: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(z.object({ backlogEntryId: z.number().positive() }))
    .query(async ({ input }) => {
      return await backlogEntryService.getBacklogEntryById(
        pool,
        input.backlogEntryId
      );
    }),

  /**
   * Get all backlog entries with a specific status for the current user
   * @example
   * const completedEntries = await trpc.backlog.getEntriesByStatus.query({ status: "Completed" })
   */
  getEntriesByStatus: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(
      z.object({
        status: z.enum(["Backlog", "Playing", "Completed", "Dropped"]),
      })
    )
    .query(async ({ ctx, input }) => {
      const userId = parseInt(ctx.session?.user?.id ?? String(TEST_USER_ID));
      return await backlogEntryService.getBacklogEntriesByStatus(pool, {
        userId,
        status: input.status,
      });
    }),

  /**
   * Get all categories for the current user
   * @example
   * const categories = await trpc.backlog.getCategories.query()
   */
  getCategories: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .query(async ({ ctx }) => {
    const userId = parseInt(ctx.session?.user?.id ?? String(TEST_USER_ID));
    return await categoryService.getCategoriesByUser(pool, userId);
  }),

  /**
   * Get all categories for a specific backlog entry
   * @example
   * const categories = await trpc.backlog.getCategoriesForEntry.query({ backlogEntryId: 1 })
   */
  getCategoriesForEntry: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(z.object({ backlogEntryId: z.number().positive() }))
    .query(async ({ input }) => {
      return await backlogEntryService.getCategoriesForBacklogEntry(
        pool,
        input.backlogEntryId
      );
    }),

  /**
   * Get all backlog entries in a specific category
   * @example
   * const entries = await trpc.backlog.getEntriesForCategory.query({ categoryId: 1 })
   */
  getEntriesForCategory: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(z.object({ categoryId: z.number().positive() }))
    .query(async ({ input }) => {
      return await backlogEntryService.getBacklogEntriesForCategory(
        pool,
        input.categoryId
      );
    }),

  /**
   * UPDATE PROCEDURES
   */

  /**
   * Update a backlog entry
   * @example
   * await trpc.backlog.updateEntry.mutate({
   *   backlogEntryId: 1,
   *   title: "Updated Title",
   *   status: "Playing",
   *   ...otherFields
   * })
   */
  updateEntry: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(
      z.object({
        backlogEntryId: z.number().positive(),
        title: z.string().min(1).optional(),
        genre: z.array(z.string()).optional(),
        platform: z.array(z.string()).optional(),
        status: z.string().optional(),
        owned: z.boolean().optional(),
        interest: z.number().min(0).max(10).optional(),
        releaseDate: z.date().optional(),
        imageLink: z.string().optional(),
        mainTime: z.number().positive().optional(),
        mainPlusExtraTime: z.number().positive().optional(),
        completionTime: z.number().positive().optional(),
        reviewStars: z.number().min(0).max(5).optional(),
        review: z.string().optional(),
        note: z.string().optional(),
      })
    )
    .mutation(async ({ input }) => {
      const dbInput = {
        ...input,
        genre: input.genre ? input.genre.join(", ") : undefined,
        platform: input.platform ? input.platform.join(", ") : undefined,
        reviewStars: input.reviewStars ? Math.round(input.reviewStars) : undefined,
      };
      return await backlogEntryService.updateBacklogEntry(pool, dbInput);
    }),

  /**
   * Update a category
   * @example
   * await trpc.backlog.updateCategory.mutate({
   *   categoryId: 1,
   *   categoryName: "Updated Name",
   *   color: "#FF0000",
   *   description: "Updated description"
   * })
   */
  updateCategory: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(
      z.object({
        categoryId: z.number().positive(),
        categoryName: z.string().min(1).optional(),
        color: z.string().regex(/^#[0-9A-F]{6}$/i).optional(),
        description: z.string().optional(),
      })
    )
    .mutation(async ({ input }) => {
      return await categoryService.updateCategory(pool, input);
    }),

  /**
   * DELETE PROCEDURES
   */

  /**
   * Delete a backlog entry
   * @example
   * await trpc.backlog.deleteEntry.mutate({ backlogEntryId: 1 })
   */
  deleteEntry: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(z.object({ backlogEntryId: z.number().positive() }))
    .mutation(async ({ input }) => {
      return await backlogEntryService.deleteBacklogEntry(
        pool,
        input.backlogEntryId
      );
    }),

  /**
   * Delete a category
   * @example
   * await trpc.backlog.deleteCategory.mutate({ categoryId: 1 })
   */
  deleteCategory: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(z.object({ categoryId: z.number().positive() }))
    .mutation(async ({ input }) => {
      return await categoryService.deleteCategory(pool, input.categoryId);
    }),

  /**
   * Remove a category from a backlog entry
   * @example
   * await trpc.backlog.removeCategoryFromEntry.mutate({
   *   categoryId: 1,
   *   backlogEntryId: 5
   * })
   */
  removeCategoryFromEntry: publicProcedure // TODO: Change back to protectedProcedure after auth merge
    .input(
      z.object({
        categoryId: z.number().positive(),
        backlogEntryId: z.number().positive(),
      })
    )
    .mutation(async ({ input }) => {
      return await backlogEntryService.removeBacklogEntryFromCategory(
        pool,
        input
      );
    }),
});
