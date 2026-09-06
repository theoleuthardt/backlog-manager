"use client";

import React, {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  useCallback,
} from "react";
import { useQueryClient } from "@tanstack/react-query";
import {
  getCurrentUser,
  login as apiLogin,
  logout as apiLogout,
  type CurrentUser,
  type LoginOutcome,
} from "~/lib/api/auth";
import { getToken, onTokenCleared } from "~/lib/api/token";
import { verifyTwoFactorLogin as apiVerifyTwoFactorLogin } from "~/lib/api/twoFactor";

interface AuthContextType {
  user: CurrentUser | null;
  /** True until the initial "is there a valid stored token" check resolves. */
  isLoading: boolean;
  login: (email: string, password: string) => Promise<LoginOutcome>;
  completeTwoFactorLogin: (challengeToken: string, code: string) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const queryClient = useQueryClient();
  // Bumped on every login()/logout()/token-cleared event so a
  // getCurrentUser() call that was already in flight when one of those
  // happened can tell its result is stale and skip applying it - otherwise
  // a slow request started before a logout (or before a second login)
  // could resolve afterwards and silently resurrect the old session.
  const sessionGeneration = useRef(0);

  const refreshUser = useCallback(async () => {
    const generation = ++sessionGeneration.current;
    if (!getToken()) {
      if (sessionGeneration.current === generation) setUser(null);
      return;
    }
    try {
      const currentUser = await getCurrentUser();
      if (sessionGeneration.current === generation) setUser(currentUser);
    } catch {
      // Stored token is missing/expired/invalid - the apiClient's
      // response middleware already cleared it on a 401.
      if (sessionGeneration.current === generation) setUser(null);
    }
  }, []);

  useEffect(() => {
    // Fires on an explicit logout() below (via apiLogout -> clearToken)
    // and, importantly, also on a 401 from any request at any time - a
    // token that expires mid-session needs to drop `user` and the cached
    // data just as much as an explicit logout does.
    return onTokenCleared(() => {
      sessionGeneration.current++;
      setUser(null);
      queryClient.clear();
    });
  }, [queryClient]);

  useEffect(() => {
    // The `ignore` flag (not the generation ref above) guards against
    // React Strict Mode's dev-only double-invoke of this exact effect:
    // without it, the first ("throwaway") invocation's refreshUser() can
    // still resolve and flip isLoading to false via this same finally
    // block, even though the generation check above correctly stopped it
    // from calling setUser - RequireAuth would then briefly see
    // `isLoading: false, user: null` and redirect to /login before the
    // second invocation's request (the one that actually matters) lands.
    let ignore = false;
    async function checkStoredToken() {
      try {
        await refreshUser();
      } finally {
        if (!ignore) setIsLoading(false);
      }
    }
    void checkStoredToken();
    return () => {
      ignore = true;
    };
  }, [refreshUser]);

  const login = useCallback(
    async (email: string, password: string): Promise<LoginOutcome> => {
      sessionGeneration.current++;
      const outcome = await apiLogin(email, password);
      if (outcome.status === "success") {
        await refreshUser();
      }
      return outcome;
    },
    [refreshUser],
  );

  const completeTwoFactorLogin = useCallback(
    async (challengeToken: string, code: string) => {
      sessionGeneration.current++;
      await apiVerifyTwoFactorLogin(challengeToken, code);
      await refreshUser();
    },
    [refreshUser],
  );

  const logout = useCallback(() => {
    // apiLogout() clears the token, which triggers the onTokenCleared
    // listener above - that's what actually drops `user` and the cache,
    // so both a manual logout and an automatic 401 go through one path.
    apiLogout();
  }, []);

  return (
    <AuthContext.Provider
      value={{ user, isLoading, login, completeTwoFactorLogin, logout, refreshUser }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
