import { apiClient, apiErrorMessage } from "./client";
import type { components } from "./schema";

export interface Backup {
  id: number;
  kind: string;
  name: string | null;
  createdAt: string;
  entryCount: number;
  categoryCount: number;
}

export interface RestoreResult {
  entryCount: number;
  categoryCount: number;
  safetyBackupId: number | null;
}

function toBackup(backup: components["schemas"]["BackupSummary"]): Backup {
  return {
    id: backup.id,
    kind: backup.kind,
    name: backup.name ?? null,
    createdAt: backup.created_at,
    entryCount: backup.entry_count,
    categoryCount: backup.category_count,
  };
}

const DOWNLOAD_URL_LIFETIME_MS = 10_000;

export async function listBackups(): Promise<Backup[]> {
  const { data, error } = await apiClient.GET("/api/backups");
  if (error) throw new Error(apiErrorMessage(error, "Failed to load backups"));
  return data.map(toBackup);
}

export async function createBackup(): Promise<Backup> {
  const { data, error } = await apiClient.POST("/api/backups");
  if (error) throw new Error(apiErrorMessage(error, "Failed to create backup"));
  return toBackup(data);
}

export async function restoreBackup(backupId: number): Promise<RestoreResult> {
  const { data, error } = await apiClient.POST(
    "/api/backups/{backup_id}/restore",
    { params: { path: { backup_id: backupId } } },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to restore backup"));
  return {
    entryCount: data.entry_count,
    categoryCount: data.category_count,
    safetyBackupId: data.safety_backup_id ?? null,
  };
}

export async function renameBackup(
  backupId: number,
  name: string | null,
): Promise<Backup> {
  const { data, error } = await apiClient.PUT("/api/backups/{backup_id}", {
    params: { path: { backup_id: backupId } },
    body: { name },
  });
  if (error) throw new Error(apiErrorMessage(error, "Failed to rename backup"));
  return toBackup(data);
}

export async function deleteBackup(backupId: number): Promise<void> {
  const { error } = await apiClient.DELETE("/api/backups/{backup_id}", {
    params: { path: { backup_id: backupId } },
  });
  if (error) throw new Error(apiErrorMessage(error, "Failed to delete backup"));
}

/**
 * The download endpoint needs the Bearer token, so a plain link can't
 * fetch it - this pulls the JSON through the authenticated client and
 * hands it to the browser as a file.
 */
export async function downloadBackup(backupId: number): Promise<void> {
  const { data, error } = await apiClient.GET(
    "/api/backups/{backup_id}/download",
    { params: { path: { backup_id: backupId } }, parseAs: "blob" },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to download backup"));

  const url = URL.createObjectURL(data);
  const link = document.createElement("a");
  link.href = url;
  link.download = `backlog-backup-${backupId}.json`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), DOWNLOAD_URL_LIFETIME_MS);
}
