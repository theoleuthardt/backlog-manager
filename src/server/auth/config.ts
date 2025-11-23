import { type DefaultSession, type NextAuthConfig } from "next-auth";
import DiscordProvider from "next-auth/providers/discord";
import GitHubProvider from "next-auth/providers/github";
import CredentialProvider from "next-auth/providers/credentials";
import { getUserByEmail } from "../db/CRUD/read";
import pool from "../db";
import argon2 from "argon2";
import { createUser } from "../db/CRUD/create";

declare module "next-auth" {
  interface Session extends DefaultSession {
    user: {
      id: string;
      steamId: string | null;
    } & DefaultSession["user"];
  }

  interface User {
    steamId?: string | null;
  }
}

export const authConfig: NextAuthConfig = {
  session: {
    strategy: "jwt",
  },
  providers: [
    DiscordProvider,
    GitHubProvider,
    CredentialProvider({
      name: "Credentials",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) return null;
      
        try {
          const dbUser = await getUserByEmail(pool, credentials.email as string);
          if (!dbUser) return null;
      
          const isValid = await argon2.verify(dbUser.PasswordHash, credentials.password as string);
          if (!isValid) return null;
      
          const user = {
            id: dbUser.id,
            username: dbUser.Username ?? null,
            email: dbUser.Email ?? null,
            steamId: dbUser.SteamId ?? null
          };
      
          console.log("Authorize User:", user);
          return user;
        } catch (error) {
          console.error("Error in authorize:", error);
          return null;
        }
      },
    }),
  ],
  callbacks: {
    async signIn({ user }) {
      const email = user.email;
      if (!email) return false;
    
      const dbUser = await getUserByEmail(pool, email);
    
      if (!dbUser) {
        
    
        await createUser(pool, {
          username: user.name ?? email,
          email: email,
          passwordHash: "",}); // Empty password hash for OAuth users
      }
    
      return true;
    },
    async jwt({ token, user }) {
      if (user) {
        token.id = user.id;
        token.steamId = user.steamId ?? null;
      }
      return token;
    },
    
    async session({ session, token }) {
      const dbUser = await getUserByEmail(pool, session.user.email);
    
      const enrichedSession = {
        ...session,
        user: {
          ...session.user,
          id: dbUser?.UserID ?? null,
          steamId: dbUser?.SteamId ?? null,
        },
      };
        
      return enrichedSession;
    }
    
  },
};