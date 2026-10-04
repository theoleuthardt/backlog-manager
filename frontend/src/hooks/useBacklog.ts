import { useCallback, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useBacklogSpaceId } from "~/app/context/BacklogScopeContext";
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
const CATEGORIES_KEY = ["categories"] as const;
const ENTRY_CATEGORIES_KEY = ["entry-categories"] as const;

/**
 * Cache keys carry the backlog scope (a shared space id, or "personal")
 * as their last element, so the personal backlog and a space never share
 * cached data. Invalidating by the bare key prefix still refreshes both,
 * which is what a Steam sync wants since it touches both.
 */
function scopedKey<K extends readonly string[]>(
  key: K,
  spaceId: number | undefined,
) {
  return [...key, spaceId ?? "personal"] as const;
}

export function useBacklogEntries() {
  const spaceId = useBacklogSpaceId();
  return useQuery({
    queryKey: scopedKey(ENTRIES_KEY, spaceId),
    queryFn: () => backlogApi.getEntries(spaceId),
  });
}

export function useCustomStatuses() {
  const spaceId = useBacklogSpaceId();
  return useQuery({
    queryKey: scopedKey(CUSTOM_STATUSES_KEY, spaceId),
    queryFn: () => backlogApi.getCustomStatuses(spaceId),
  });
}

export function useCreateCustomStatus() {
  const queryClient = useQueryClient();
  const spaceId = useBacklogSpaceId();
  return useMutation({
    mutationFn: (name: string) => backlogApi.createCustomStatus(name, spaceId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: CUSTOM_STATUSES_KEY });
    },
  });
}

export function useDeleteCustomStatus() {
  const queryClient = useQueryClient();
  const spaceId = useBacklogSpaceId();
  return useMutation({
    mutationFn: (statusId: number) =>
      backlogApi.deleteCustomStatus(statusId, spaceId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: CUSTOM_STATUSES_KEY });
    },
  });
}

/**
 * `targetSpaceId` lets the creation tool pick where the entry goes
 * independently of the scope the page is rendered in; left undefined it
 * follows the surrounding scope.
 */
export function useCreateBacklogEntry(targetSpaceId?: number) {
  const queryClient = useQueryClient();
  const scopeSpaceId = useBacklogSpaceId();
  const spaceId = targetSpaceId ?? scopeSpaceId;
  return useMutation({
    mutationFn: (input: backlogApi.CreateBacklogEntryInput) =>
      backlogApi.createEntry(input, spaceId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
    },
  });
}

export function useUpdateBacklogEntry() {
  const queryClient = useQueryClient();
  const spaceId = useBacklogSpaceId();
  return useMutation({
    mutationFn: ({
      entryId,
      changes,
    }: {
      entryId: number;
      changes: backlogApi.UpdateBacklogEntryInput;
    }) => backlogApi.updateEntry(entryId, changes, spaceId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
    },
  });
}

const MOVE_ENTRY_MUTATION_KEY = ["move-entry-status"];

/**
 * Moves an entry to another status (dashboard drag and drop). The
 * cached list is updated immediately so the card jumps groups without
 * waiting for the round trip. A failed request reverts only that one
 * entry's status rather than restoring the whole list to its
 * pre-mutation snapshot - dragging a second card while this one's
 * request is still in flight applies its own optimistic update to the
 * same cached list, and a wholesale restore would discard that
 * unrelated change too. For the same reason, onSettled only
 * invalidates once no sibling move is still pending - invalidating
 * while one is would refetch the server's not-yet-updated state for
 * that other move and briefly overwrite its optimistic update, right
 * before its own settle corrects it again.
 */
export function useMoveEntryToStatus() {
  const queryClient = useQueryClient();
  const spaceId = useBacklogSpaceId();
  const entriesKey = scopedKey(ENTRIES_KEY, spaceId);
  return useMutation({
    mutationKey: MOVE_ENTRY_MUTATION_KEY,
    mutationFn: ({ entryId, status }: { entryId: number; status: string }) =>
      backlogApi.updateEntry(entryId, { status }, spaceId),
    onMutate: async ({ entryId, status }) => {
      await queryClient.cancelQueries({ queryKey: entriesKey });
      const previousEntry = queryClient
        .getQueryData<backlogApi.BacklogEntryData[]>(entriesKey)
        ?.find((entry) => entry.id === entryId);
      queryClient.setQueryData<backlogApi.BacklogEntryData[]>(
        entriesKey,
        (entries) =>
          entries?.map((entry) =>
            entry.id === entryId ? { ...entry, status } : entry,
          ),
      );
      return { previousStatus: previousEntry?.status };
    },
    onError: (_error, { entryId }, context) => {
      if (context?.previousStatus === undefined) return;
      queryClient.setQueryData<backlogApi.BacklogEntryData[]>(
        entriesKey,
        (entries) =>
          entries?.map((entry) =>
            entry.id === entryId
              ? { ...entry, status: context.previousStatus! }
              : entry,
          ),
      );
    },
    onSettled: async () => {
      const stillMoving = queryClient.isMutating({
        mutationKey: MOVE_ENTRY_MUTATION_KEY,
      });
      if (stillMoving <= 1) {
        await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
      }
    },
  });
}

/**
 * Every category of the user, for pickers and filters.
 */
export function useCategories() {
  const spaceId = useBacklogSpaceId();
  return useQuery({
    queryKey: scopedKey(CATEGORIES_KEY, spaceId),
    queryFn: () => backlogApi.getCategories(spaceId),
  });
}

/**
 * Maps entry id -> the categories it belongs to (alphabetical by name).
 * Entries carry no category data themselves, so this walks the category
 * endpoints - one request per category - and is the single source the
 * dashboard uses for sorting, grouping, filtering and the entry dialog.
 */
export function useEntryCategories() {
  const spaceId = useBacklogSpaceId();
  return useQuery({
    queryKey: scopedKey(ENTRY_CATEGORIES_KEY, spaceId),
    queryFn: async () => {
      const categories = (await backlogApi.getCategories(spaceId)).sort(
        (a, b) => a.name.localeCompare(b.name),
      );
      const entriesPerCategory = await Promise.all(
        categories.map((category) =>
          backlogApi.getEntriesForCategory(category.id, spaceId),
        ),
      );
      const byEntry = new Map<number, backlogApi.CategoryData[]>();
      categories.forEach((category, index) => {
        for (const entry of entriesPerCategory[index] ?? []) {
          byEntry.set(entry.id, [...(byEntry.get(entry.id) ?? []), category]);
        }
      });
      return byEntry;
    },
  });
}

function useInvalidateCategories() {
  const queryClient = useQueryClient();
  return async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: CATEGORIES_KEY }),
      queryClient.invalidateQueries({ queryKey: ENTRY_CATEGORIES_KEY }),
    ]);
  };
}

export function useCreateCategory() {
  const invalidate = useInvalidateCategories();
  const spaceId = useBacklogSpaceId();
  return useMutation({
    mutationFn: (input: {
      categoryName: string;
      color?: string;
      description?: string;
    }) => backlogApi.createCategory(input, spaceId),
    onSuccess: invalidate,
  });
}

export function useUpdateCategory() {
  const invalidate = useInvalidateCategories();
  const spaceId = useBacklogSpaceId();
  return useMutation({
    mutationFn: ({
      categoryId,
      changes,
    }: {
      categoryId: number;
      changes: { categoryName?: string; color?: string };
    }) => backlogApi.updateCategory(categoryId, changes, spaceId),
    onSuccess: invalidate,
  });
}

export function useDeleteCategory() {
  const invalidate = useInvalidateCategories();
  const spaceId = useBacklogSpaceId();
  return useMutation({
    mutationFn: (categoryId: number) =>
      backlogApi.deleteCategory(categoryId, spaceId),
    onSuccess: invalidate,
  });
}

export function useSetEntryCategory() {
  const invalidate = useInvalidateCategories();
  const spaceId = useBacklogSpaceId();
  return useMutation({
    mutationFn: ({
      entryId,
      categoryId,
      assigned,
    }: {
      entryId: number;
      categoryId: number;
      assigned: boolean;
    }) =>
      assigned
        ? backlogApi.addCategoryToEntry(entryId, categoryId, spaceId)
        : backlogApi.removeCategoryFromEntry(entryId, categoryId, spaceId),
    onSuccess: invalidate,
  });
}

export function useDeleteBacklogEntry() {
  const queryClient = useQueryClient();
  const spaceId = useBacklogSpaceId();
  return useMutation({
    mutationFn: (entryId: number) => backlogApi.deleteEntry(entryId, spaceId),
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
  run: (appIds: number[]) => Promise<backlogApi.BacklogEntryData[]>;
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
        const entries = await importSteamLibraryAppIdsStream(
          appIds,
          setProgress,
        );
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
