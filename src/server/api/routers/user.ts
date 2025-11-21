import { z } from "zod";
import { createTRPCRouter, protectedProcedure, publicProcedure } from "~/server/api/trpc";
import pool from "~/server/db/index";
import * as userService from "~/server/services/userService";

/**
 * User Router
 *
 * Handles user-related operations like authentication, profile management, etc.
 * Most procedures require authentication (protectedProcedure).
 */
export const userRouter = createTRPCRouter({
  /**
   * CREATE PROCEDURES
   */

  /**
   * Create a new user (Registration)
   * @example
   * await trpc.user.createUser.mutate({
   *   username: "john_doe",
   *   email: "john@example.com",
   *   passwordHash: "hashed_password"
   * })
   */
  createUser: publicProcedure
    .input(
      z.object({
        username: z.string().min(3, "Username must be at least 3 characters"),
        email: z.string().email("Invalid email address"),
        passwordHash: z.string().min(1, "Password hash is required"),
      })
    )
    .mutation(async ({ input }) => {
      return await userService.createUser(pool, {
        username: input.username,
        email: input.email,
        passwordHash: input.passwordHash,
      });
    }),

  /**
   * READ PROCEDURES
   */

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
   * Get a user by ID (Admin only - in production, add permission check)
   * @example
   * const user = await trpc.user.getUserById.query({ userId: 1 })
   */
  getUserById: protectedProcedure
    .input(z.object({ userId: z.number().positive() }))
    .query(async ({ input }) => {
      return await userService.getUserById(pool, input.userId);
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
   * Get all users (Admin only - in production, add permission check)
   * @example
   * const allUsers = await trpc.user.getAllUsers.query()
   */
  getAllUsers: protectedProcedure.query(async () => {
    return await userService.getAllUsers(pool);
  }),

  /**
   * UPDATE PROCEDURES
   */

  /**
   * Update the current user's profile
   * @example
   * await trpc.user.updateCurrentUser.mutate({
   *   username: "new_username",
   *   email: "newemail@example.com",
   *   passwordHash: "new_hashed_password"
   * })
   */
  updateCurrentUser: protectedProcedure
    .input(
      z.object({
        username: z.string().min(3, "Username must be at least 3 characters"),
        email: z.string().email("Invalid email address"),
        passwordHash: z.string().min(1, "Password hash is required"),
      })
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
        passwordHash: input.passwordHash,
      });
    }),

  /**
   * Update a specific user (Admin only - in production, add permission check)
   * @example
   * await trpc.user.updateUser.mutate({
   *   userId: 1,
   *   username: "updated_username",
   *   email: "updated@example.com",
   *   passwordHash: "new_hashed_password"
   * })
   */
  updateUser: protectedProcedure
    .input(
      z.object({
        userId: z.number().positive(),
        username: z.string().min(3, "Username must be at least 3 characters"),
        email: z.string().email("Invalid email address"),
        passwordHash: z.string().min(1, "Password hash is required"),
      })
    )
    .mutation(async ({ input }) => {
      return await userService.updateUser(pool, {
        userId: input.userId,
        username: input.username,
        email: input.email,
        passwordHash: input.passwordHash,
      });
    }),

  /**
   * DELETE PROCEDURES
   */

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

  /**
   * Delete a specific user (Admin only - in production, add permission check)
   * @example
   * await trpc.user.deleteUser.mutate({ userId: 1 })
   */
  deleteUser: protectedProcedure
    .input(z.object({ userId: z.number().positive() }))
    .mutation(async ({ input }) => {
      return await userService.deleteUser(pool, input.userId);
    }),
});

