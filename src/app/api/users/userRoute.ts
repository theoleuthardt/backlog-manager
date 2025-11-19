import { z } from "zod";
import argon2 from "argon2";

import {
  createTRPCRouter,
  publicProcedure,
  protectedProcedure,
} from "~/server/api/trpc";

import pool from "~/server/db";
import { createUser } from "~/server/db/CRUD/create";
import { getUserByEmail, getUserById, getUserByUsername, getAllUsers } from "~/server/db/CRUD/read";
import { updateUserByEmail } from "~/server/db/CRUD/update";
import { deleteUser } from "~/server/db/CRUD/delete";

export const userRouter = createTRPCRouter({

  register: publicProcedure
    .input(
      z.object({
        username: z.string(),
        email: z.string(),
        password: z.string(),
        steamId: z.string().optional(),
      })
    )
    .mutation(async ({ input }) => {
      try {
        const passwordHash = await argon2.hash(input.password);

        const steamId = input.steamId ?? undefined; 

        const user = await createUser(
          pool,
          input.username,
          input.email,
          passwordHash,
          steamId
        );

        return { user };
      } catch (error: any) {
        if (error.code === "23505") {
          throw new Error("Email or username already in use.");
        }
        throw new Error("Internal server error");
      }
    }),

  updateSteamId: protectedProcedure
    .input(
      z.object({
        steamId: z.string().min(1),
      })
    )
    .mutation(async ({ input, ctx }) => {
      if(!input.steamId) throw new Error("Missing steamId");

      const email = ctx.session.user.email;  
      if (!email) throw new Error("Missing email");

      const user = await getUserByEmail(pool, email);
      if (!user) throw new Error("User does not exist.");

      const updated = await updateUserByEmail(
        pool,
        email,
        user.Username,
        user.PasswordHash,
        input.steamId
      );

      return {
        message: "Steam ID updated",
        user: updated,
      };
    }),

  deleteUser: protectedProcedure
    .input(z.object({ userId: z.number() }))
    .mutation(async ({ input }) => {
      const deleted = await deleteUser(pool, input.userId);
      return {
        message: "User deleted",
        user: deleted,
      };
    }),

  getAllUsers: publicProcedure
    .query(async () => {
      const users = await getAllUsers(pool);
      return users;
    }),

  getUserById: publicProcedure
    .input(z.object({ userId: z.number() }))
    .query(async ({ input }) => {
      const user = await getUserById(pool, input.userId);
      if (!user) throw new Error("User not found");
      return user;
    }),

  getUserByUsername: publicProcedure
    .input(z.object({ username: z.string() }))
    .query(async ({ input }) => {
      const user = await getUserByUsername(pool, input.username);
      if (!user) throw new Error("User not found");
      return user;
    }),

  getUserByEmail: protectedProcedure
    .input(z.object({ email: z.string() }))
    .query(async ({ input }) => {
      const user = await getUserByEmail(pool, input.email);
      if (!user) throw new Error("User not found");
      return user;
    }),

});
