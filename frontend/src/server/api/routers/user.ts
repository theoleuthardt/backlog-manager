import { z } from "zod";
import { createTRPCRouter, protectedProcedure, publicProcedure } from "~/server/api/trpc";
import pool from "~/server/db/index";
import * as userService from "~/server/services/userService";
import argon2 from "argon2";

/**
 * User Router
 *
 * Handles user-related operations for the currently authenticated user.
 * There is no public self-registration or unrestricted admin-by-id
 * access here - both were removed since the Python/Litestar backend
 * (backend/) is taking over user management with a real admin role
 * and an actual permission check (see backend/routes/user.py). This
 * tRPC router is being phased out along with the rest of the Next.js
 * backend, not extended further.
 */
export const userRouter = createTRPCRouter({
  /**
   * Get the current authenticated user
   * @example
   * const user = await trpc.user.getCurrentUser.query()
   */
  getCurrentUser: protectedProcedure.query(async ({ ctx }) => {
    if (!ctx.session?.user?.id) {
      throw new Error("User ID not found in session");
    }
    const userId = parseInt(ctx.session.user.id);
    return await userService.getUserById(pool, userId);
  }),

  /**
   * Get a user by username
   * @example
   * const user = await trpc.user.getUserByUsername.query({ username: "john_doe" })
   */
  getUserByUsername: publicProcedure
    .input(z.object({ username: z.string().min(1) }))
    .query(async ({ input }) => {
      return await userService.getUserByUsername(pool, input.username);
    }),

  /**
   * Update the current user's profile
   * @example
   * await trpc.user.updateCurrentUser.mutate({
   *   username: "new_username",
   *   email: "newemail@example.com",
   *   passwordHash: "new_plaintext_password"
   * })
   */
  updateCurrentUser: protectedProcedure
    .input(
      z.object({
        username: z.string().min(1).optional(),
        email: z.string().email().optional(),
        passwordHash: z.string().min(1).optional(),
        steamId: z.string().optional(),
      }),
    )
    .mutation(async ({ ctx, input }) => {
      if (!ctx.session?.user?.id) {
        throw new Error("User ID not found in session");
      }

      const userId = parseInt(ctx.session.user.id);

      return await userService.updateUser(pool, {
        userId,
        username: input.username,
        email: input.email,
        passwordHash: input.passwordHash
          ? await argon2.hash(input.passwordHash)
          : undefined,
        steamId: input.steamId,
      });
    }),

  /**
   * Delete the current user
   * @example
   * await trpc.user.deleteCurrentUser.mutate()
   */
  deleteCurrentUser: protectedProcedure.mutation(async ({ ctx }) => {
    if (!ctx.session?.user?.id) {
      throw new Error("User ID not found in session");
    }
    const userId = parseInt(ctx.session.user.id);
    return await userService.deleteUser(pool, userId);
  }),
});

