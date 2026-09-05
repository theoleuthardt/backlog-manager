"use client";

import React, {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
} from "react";
import {
  getCurrentUser,
  login as apiLogin,
  logout as apiLogout,
  type CurrentUser,
} from "~/lib/api/auth";
import { getToken } from "~/lib/api/token";

interface AuthContextType {
  user: CurrentUser | null;
  /** True until the initial "is there a valid stored token" check resolves. */
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const refreshUser = useCallback(async () => {
    if (!getToken()) {
      setUser(null);
      return;
    }
    try {
      setUser(await getCurrentUser());
    } catch {
      // Stored token is missing/expired/invalid - the apiClient's
      // response middleware already cleared it on a 401.
      setUser(null);
    }
  }, []);

  useEffect(() => {
    async function checkStoredToken() {
      try {
        await refreshUser();
      } finally {
        setIsLoading(false);
      }
    }
    void checkStoredToken();
  }, [refreshUser]);

  const login = useCallback(
    async (email: string, password: string) => {
      await apiLogin(email, password);
      await refreshUser();
    },
    [refreshUser],
  );

  const logout = useCallback(() => {
    apiLogout();
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider
      value={{ user, isLoading, login, logout, refreshUser }}
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
