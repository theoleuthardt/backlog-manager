import { postRouter } from "./routers/post";
import { backlogRouter } from "./routers/backlog";
import { userRouter } from "./routers/user";
import { HLTBSearchRouter } from "./routers/hltb";
import { csvRouter } from "./routers/csv";
import { createCallerFactory, createTRPCRouter } from "./trpc";

/**
 * This is the primary router for your server.
 *
 * All routers added in /api/routers should be manually added here.
 */
export const appRouter = createTRPCRouter({
  post: postRouter,
  backlog: backlogRouter,
  user: userRouter,
  csv: csvRouter,
  gameSearch: HLTBSearchRouter,
});

// export type definition of API
export type AppRouter = typeof appRouter;

/**
 * Create a server-side caller for the tRPC API.
 * @example
 * const trpc = createCaller(createContext);
 * const res = await trpc.post.all();
 *       ^? Post[]
 */
export const createCaller = createCallerFactory(appRouter);
