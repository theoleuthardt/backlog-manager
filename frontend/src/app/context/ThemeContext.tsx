"use client";

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  useSyncExternalStore,
} from "react";
import dynamic from "next/dynamic";
import { toast } from "sonner";
import { useAuth } from "~/app/context/AuthContext";
import { updateCurrentUser } from "~/lib/api/user";
import {
  DEFAULT_THEME_ID,
  THEME_CACHE_KEY,
  resolveTheme,
  themeCssVariables,
  type CustomTheme,
  type ResolvedTheme,
  type ThemeColors,
} from "~/lib/themes";

const FreakyBackground = dynamic(
  () =>
    import("~/app/_components/FreakyBackground").then(
      (module) => module.FreakyBackground,
    ),
  { ssr: false },
);

interface ThemeSelection {
  id: string;
  customThemes: CustomTheme[];
}

interface ThemeContextType {
  theme: ResolvedTheme;
  customThemes: CustomTheme[];
  setTheme: (themeId: string) => Promise<void>;
  saveCustomTheme: (theme: CustomTheme) => Promise<void>;
  deleteCustomTheme: (themeId: string) => Promise<void>;
  previewColors: (colors: ThemeColors | null) => void;
}

const ThemeContext = createContext<ThemeContextType | null>(null);

const DEFAULT_SELECTION: ThemeSelection = {
  id: DEFAULT_THEME_ID,
  customThemes: [],
};

const cacheListeners = new Set<() => void>();

function subscribeToCache(listener: () => void): () => void {
  cacheListeners.add(listener);
  window.addEventListener("storage", listener);
  return () => {
    cacheListeners.delete(listener);
    window.removeEventListener("storage", listener);
  };
}

function readCacheSnapshot(): string | null {
  try {
    return window.localStorage.getItem(THEME_CACHE_KEY);
  } catch {
    return null;
  }
}

function readServerSnapshot(): string | null {
  return null;
}

function parseSelection(raw: string | null): ThemeSelection {
  if (!raw) return DEFAULT_SELECTION;
  try {
    const parsed = JSON.parse(raw) as Partial<ThemeSelection>;
    return {
      id: typeof parsed.id === "string" ? parsed.id : DEFAULT_THEME_ID,
      customThemes: Array.isArray(parsed.customThemes)
        ? parsed.customThemes
        : [],
    };
  } catch {
    return DEFAULT_SELECTION;
  }
}

/**
 * Stores the selection together with its resolved CSS variables under
 * THEME_CACHE_KEY. The inline boot script in layout.tsx reads the
 * variables back before first paint so a reload never flashes the
 * default theme while the user request is still in flight, and the
 * provider itself treats this cache as its store, so a change made
 * while logged out (login page) survives too.
 */
function writeCache(selection: ThemeSelection): void {
  const theme = resolveTheme(selection.id, selection.customThemes);
  try {
    window.localStorage.setItem(
      THEME_CACHE_KEY,
      JSON.stringify({
        id: selection.id,
        customThemes: selection.customThemes,
        dataTheme: theme.builtin ? theme.id : "custom",
        colorScheme: theme.id === "light" ? "light" : "dark",
        variables: themeCssVariables(theme.colors),
      }),
    );
  } catch {
    return;
  }
  cacheListeners.forEach((listener) => listener());
}

function applyTheme(theme: ResolvedTheme, colors: ThemeColors): void {
  const root = document.documentElement;
  for (const [name, value] of Object.entries(themeCssVariables(colors))) {
    root.style.setProperty(name, value);
  }
  root.dataset.theme = theme.builtin ? theme.id : "custom";
  root.style.colorScheme = theme.id === "light" ? "light" : "dark";
}

function subscribeToNothing(): () => void {
  return () => undefined;
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const { user, refreshUser } = useAuth();
  const [preview, setPreview] = useState<ThemeColors | null>(null);
  const isHydrated = useSyncExternalStore(
    subscribeToNothing,
    () => true,
    () => false,
  );
  const rawCache = useSyncExternalStore(
    subscribeToCache,
    readCacheSnapshot,
    readServerSnapshot,
  );
  const selection = useMemo(() => parseSelection(rawCache), [rawCache]);

  const userTheme = user?.theme;
  const userCustomThemes = user?.customThemes;
  useEffect(() => {
    if (userTheme === undefined || userCustomThemes === undefined) return;
    writeCache({ id: userTheme, customThemes: userCustomThemes });
  }, [userTheme, userCustomThemes]);

  const theme = useMemo(
    () => resolveTheme(selection.id, selection.customThemes),
    [selection],
  );

  useEffect(() => {
    if (isHydrated) applyTheme(theme, preview ?? theme.colors);
  }, [isHydrated, theme, preview]);

  const persist = useCallback(
    async (next: ThemeSelection) => {
      const previous = selection;
      writeCache(next);
      if (!user) return;
      try {
        await updateCurrentUser({
          theme: next.id,
          customThemes: next.customThemes,
        });
        await refreshUser();
      } catch (error) {
        writeCache(previous);
        toast.error(
          error instanceof Error ? error.message : "Failed to save theme",
        );
      }
    },
    [selection, user, refreshUser],
  );

  const setTheme = useCallback(
    (themeId: string) =>
      persist({ id: themeId, customThemes: selection.customThemes }),
    [persist, selection.customThemes],
  );

  const saveCustomTheme = useCallback(
    (custom: CustomTheme) => {
      const exists = selection.customThemes.some(
        (existing) => existing.id === custom.id,
      );
      return persist({
        id: custom.id,
        customThemes: exists
          ? selection.customThemes.map((existing) =>
              existing.id === custom.id ? custom : existing,
            )
          : [...selection.customThemes, custom],
      });
    },
    [persist, selection.customThemes],
  );

  const deleteCustomTheme = useCallback(
    (customId: string) =>
      persist({
        id: selection.id === customId ? DEFAULT_THEME_ID : selection.id,
        customThemes: selection.customThemes.filter(
          (existing) => existing.id !== customId,
        ),
      }),
    [persist, selection],
  );

  const value = useMemo(
    () => ({
      theme,
      customThemes: selection.customThemes,
      setTheme,
      saveCustomTheme,
      deleteCustomTheme,
      previewColors: setPreview,
    }),
    [
      theme,
      selection.customThemes,
      setTheme,
      saveCustomTheme,
      deleteCustomTheme,
    ],
  );

  return (
    <ThemeContext.Provider value={value}>
      {isHydrated && theme.id === "freaky" && !preview && <FreakyBackground />}
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme(): ThemeContextType {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
}
