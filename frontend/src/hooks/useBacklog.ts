import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as backlogApi from "~/lib/api/backlog";
import { syncSteamPlaytimes } from "~/lib/api/steam";

const ENTRIES_KEY = ["backlog-entries"] as const;

export function useBacklogEntries() {
  return useQuery({
    queryKey: ENTRIES_KEY,
    queryFn: backlogApi.getEntries,
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

export function useSyncSteamPlaytimes() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: syncSteamPlaytimes,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ENTRIES_KEY });
    },
  });
}
