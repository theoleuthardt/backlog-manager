import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as backupsApi from "~/lib/api/backups";

const BACKUPS_KEY = ["backups"] as const;

export function useBackups() {
  return useQuery({
    queryKey: BACKUPS_KEY,
    queryFn: backupsApi.listBackups,
  });
}

export function useCreateBackup() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: backupsApi.createBackup,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: BACKUPS_KEY });
    },
  });
}

export function useDeleteBackup() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: backupsApi.deleteBackup,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: BACKUPS_KEY });
    },
  });
}

export function useDownloadBackup() {
  return useMutation({
    mutationFn: backupsApi.downloadBackup,
  });
}

/**
 * A restore rewrites entries, categories and custom statuses, so every
 * cached query is refreshed rather than just the backups list.
 */
export function useRestoreBackup() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: backupsApi.restoreBackup,
    onSuccess: async () => {
      await queryClient.invalidateQueries();
    },
  });
}
