import { useCallback, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as backlogApi from "~/lib/api/backlog";
import {
  getSteamAchievements,
  importSteamLibraryStream,
  syncSteamPlaytimesStream,
  type SteamSyncProgress,
} from "~/lib/api/steam";

const ENTRIES_KEY = ["backlog-entries"] as const;
const CUSTOM_STATUSES_KEY = ["custom-statuses"] as const;

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

export function useSyncSteamPlaytimesStream(): SteamStreamState {
  return useSteamStream(syncSteamPlaytimesStream);
}

export function useImportSteamLibraryStream(): SteamStreamState {
  return useSteamStream(importSteamLibraryStream);
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
