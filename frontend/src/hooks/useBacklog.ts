import { useCallback, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as backlogApi from "~/lib/api/backlog";
import {
  getSteamAchievements,
  importSteamLibraryAppIdsStream,
  importSteamWishlistStream,
  previewSteamLibraryStream,
  syncSteamPlaytimesStream,
  type SteamPreviewItem,
  type SteamSyncProgress,
  type SteamWishlistImportItem,
} from "~/lib/api/steam";

const ENTRIES_KEY = ["backlog-entries"] as const;
const CUSTOM_STATUSES_KEY = ["custom-statuses"] as const;
const CATEGORY_NAMES_KEY = ["entry-category-names"] as const;

export function useBacklogEntries() {
  return useQuery({
    queryKey: ENTRIES_KEY,
    queryFn: backlogApi.getEntries,
  });
}

export function useCustomStatuses() {
  return useQuery({
    queryKey: CUSTOM_STATUSES_KEY,
    queryFn: backlogApi.getCustomStatuses,
  });
}

export function useCreateCustomStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: backlogApi.createCustomStatus,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: CUSTOM_STATUSES_KEY });
    },
  });
}

export function useDeleteCustomStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: backlogApi.deleteCustomStatus,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: CUSTOM_STATUSES_KEY });
    },
  });
}

export function useCreateBacklogEntry() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: backlogApi.createEntry,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
    },
  });
}

export function useUpdateBacklogEntry() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      entryId,
      changes,
    }: {
      entryId: number;
      changes: backlogApi.UpdateBacklogEntryInput;
    }) => backlogApi.updateEntry(entryId, changes),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
    },
  });
}

/**
 * Moves an entry to another status (dashboard drag and drop). The
 * cached list is updated immediately so the card jumps groups without
 * waiting for the round trip, and rolled back if the request fails.
 */
export function useMoveEntryToStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ entryId, status }: { entryId: number; status: string }) =>
      backlogApi.updateEntry(entryId, { status }),
    onMutate: async ({ entryId, status }) => {
      await queryClient.cancelQueries({ queryKey: ENTRIES_KEY });
      const previous =
        queryClient.getQueryData<backlogApi.BacklogEntryData[]>(ENTRIES_KEY);
      queryClient.setQueryData<backlogApi.BacklogEntryData[]>(
        ENTRIES_KEY,
        (entries) =>
          entries?.map((entry) =>
            entry.id === entryId ? { ...entry, status } : entry,
          ),
      );
      return { previous };
    },
    onError: (_error, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(ENTRIES_KEY, context.previous);
      }
    },
    onSettled: async () => {
      await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
    },
  });
}

/**
 * Maps entry id -> name of its first category (alphabetically) for the
 * "sort by category" option. Entries carry no category data
 * themselves, so this walks the category endpoints; it stays disabled
 * until that sort is actually selected.
 */
export function useEntryCategoryNames(enabled: boolean) {
  return useQuery({
    queryKey: CATEGORY_NAMES_KEY,
    enabled,
    queryFn: async () => {
      const categories = (await backlogApi.getCategories()).sort((a, b) =>
        a.name.localeCompare(b.name),
      );
      const entriesPerCategory = await Promise.all(
        categories.map((category) =>
          backlogApi.getEntriesForCategory(category.id),
        ),
      );
      const names = new Map<number, string>();
      categories.forEach((category, index) => {
        for (const entry of entriesPerCategory[index] ?? []) {
          if (!names.has(entry.id)) names.set(entry.id, category.name);
        }
      });
      return names;
    },
  });
}

export function useDeleteBacklogEntry() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: backlogApi.deleteEntry,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
    },
  });
}

interface SteamStreamState {
  run: () => Promise<backlogApi.BacklogEntryData[]>;
  isRunning: boolean;
  progress: SteamSyncProgress | null;
}

function useSteamStream(
  streamFn: (
    onProgress: (progress: SteamSyncProgress) => void,
  ) => Promise<backlogApi.BacklogEntryData[]>,
): SteamStreamState {
  const queryClient = useQueryClient();
  const [isRunning, setIsRunning] = useState(false);
  const [progress, setProgress] = useState<SteamSyncProgress | null>(null);

  const run = useCallback(async () => {
    setIsRunning(true);
    setProgress(null);
    try {
      const entries = await streamFn(setProgress);
      await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
      return entries;
    } finally {
      setIsRunning(false);
      setProgress(null);
    }
  }, [streamFn, queryClient]);

  return { run, isRunning, progress };
}

export function useImportSteamWishlistStream(): {
  run: (
    items: SteamWishlistImportItem[],
  ) => Promise<backlogApi.BacklogEntryData[]>;
  isRunning: boolean;
  progress: SteamSyncProgress | null;
} {
  const queryClient = useQueryClient();
  const [isRunning, setIsRunning] = useState(false);
  const [progress, setProgress] = useState<SteamSyncProgress | null>(null);

  const run = useCallback(
    async (items: SteamWishlistImportItem[]) => {
      setIsRunning(true);
      setProgress(null);
      try {
        const entries = await importSteamWishlistStream(items, setProgress);
        await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
        return entries;
      } finally {
        setIsRunning(false);
        setProgress(null);
      }
    },
    [queryClient],
  );

  return { run, isRunning, progress };
}

export function useImportSteamLibraryAppIdsStream(): {
  run: (
    appIds: number[],
  ) => Promise<backlogApi.BacklogEntryData[]>;
  isRunning: boolean;
  progress: SteamSyncProgress | null;
} {
  const queryClient = useQueryClient();
  const [isRunning, setIsRunning] = useState(false);
  const [progress, setProgress] = useState<SteamSyncProgress | null>(null);

  const run = useCallback(
    async (appIds: number[]) => {
      setIsRunning(true);
      setProgress(null);
      try {
        const entries = await importSteamLibraryAppIdsStream(appIds, setProgress);
        await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
        return entries;
      } finally {
        setIsRunning(false);
        setProgress(null);
      }
    },
    [queryClient],
  );

  return { run, isRunning, progress };
}

export function useSyncSteamPlaytimesStream(): SteamStreamState {
  return useSteamStream(syncSteamPlaytimesStream);
}

export function useSteamLibraryPreviewStream(): {
  run: () => Promise<SteamPreviewItem[]>;
  isRunning: boolean;
  progress: SteamSyncProgress | null;
} {
  const [isRunning, setIsRunning] = useState(false);
  const [progress, setProgress] = useState<SteamSyncProgress | null>(null);

  const run = useCallback(async () => {
    setIsRunning(true);
    setProgress(null);
    try {
      return await previewSteamLibraryStream(setProgress);
    } finally {
      setIsRunning(false);
      setProgress(null);
    }
  }, []);

  return { run, isRunning, progress };
}

export function useSteamAchievements(
  steamAppId: number | undefined,
  enabled = true,
) {
  return useQuery({
    queryKey: ["steam-achievements", steamAppId],
    queryFn: () => getSteamAchievements(steamAppId!),
    enabled: enabled && steamAppId !== undefined,
    refetchOnWindowFocus: false,
    staleTime: 1000 * 60 * 5,
    gcTime: 1000 * 60 * 10,
    retry: 1,
  });
}
