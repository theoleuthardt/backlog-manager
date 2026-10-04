"use client";

import { useState } from "react";
import { toast } from "sonner";
import {
  useBackups,
  useCreateBackup,
  useDeleteBackup,
  useDownloadBackup,
  useRestoreBackup,
} from "~/hooks/useBackups";
import type { Backup } from "~/lib/api/backups";
import { backupContentSummary, backupKindLabel } from "~/lib/backups";
import { Button } from "~/components/ui/button";
import {
  AlertDialog,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogCancel,
} from "~/components/ui/alert-dialog";

const OUTLINE_BUTTON =
  "border-2 border-white bg-black text-white hover:bg-white hover:text-black";
const FILLED_BUTTON =
  "border-2 border-white bg-white text-black hover:bg-gray-900 hover:text-white";

function formatBackupDate(createdAt: string): string {
  return new Date(`${createdAt}Z`).toLocaleString();
}

/**
 * Account-settings card for the backend's per-user backups: daily automatic
 * snapshots, manual ones, and the safety snapshots taken before a restore,
 * "delete all" or CSV import. Restoring replaces the whole personal backlog
 * and is itself undoable through the safety snapshot it creates.
 */
export function BackupSection() {
  const { data: backups, isLoading, isError } = useBackups();
  const createMutation = useCreateBackup();
  const deleteMutation = useDeleteBackup();
  const downloadMutation = useDownloadBackup();
  const restoreMutation = useRestoreBackup();
  const [restoreTarget, setRestoreTarget] = useState<Backup | null>(null);

  const handleCreate = () => {
    createMutation.mutate(undefined, {
      onSuccess: () => toast.success("Backup created"),
      onError: (error) => toast.error(error.message),
    });
  };

  const handleRestore = () => {
    if (!restoreTarget) return;
    restoreMutation.mutate(restoreTarget.id, {
      onSuccess: (result) => {
        toast.success(
          `Restored ${backupContentSummary(result)}.` +
            (result.safetyBackupId === null
              ? ""
              : " Your previous state was saved as a backup."),
        );
        setRestoreTarget(null);
      },
      onError: (error) => toast.error(error.message),
    });
  };

  return (
    <div className="rounded-lg border-2 border-white bg-black p-6">
      <h2 className="mb-2 text-xl font-semibold">Backups</h2>
      <p className="mb-4 text-sm text-gray-300">
        Your backlog is backed up automatically once a day, and right before
        anything destructive. Restore an earlier state if something went wrong.
      </p>
      <Button
        className={FILLED_BUTTON}
        onClick={handleCreate}
        disabled={createMutation.isPending}
      >
        {createMutation.isPending ? "Creating..." : "Back up now"}
      </Button>

      <div className="mt-4 space-y-2">
        {isLoading && <p className="text-sm text-gray-300">Loading...</p>}
        {isError && (
          <p className="text-sm text-red-400">Failed to load backups.</p>
        )}
        {backups?.length === 0 && (
          <p className="text-sm text-gray-300">No backups yet.</p>
        )}
        {backups?.map((backup) => (
          <div
            key={backup.id}
            className="flex flex-wrap items-center justify-between gap-3 rounded border border-white/40 p-3"
          >
            <div>
              <p className="text-sm font-medium">
                {backupKindLabel(backup.kind)}
                <span className="ml-2 font-normal text-gray-300">
                  {formatBackupDate(backup.createdAt)}
                </span>
              </p>
              <p className="text-xs text-gray-300">
                {backupContentSummary(backup)}
              </p>
            </div>
            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                className={OUTLINE_BUTTON}
                onClick={() => setRestoreTarget(backup)}
              >
                Restore
              </Button>
              <Button
                variant="outline"
                size="sm"
                className={OUTLINE_BUTTON}
                onClick={() =>
                  downloadMutation.mutate(backup.id, {
                    onError: (error) => toast.error(error.message),
                  })
                }
                disabled={downloadMutation.isPending}
              >
                Download
              </Button>
              <Button
                variant="outline"
                size="sm"
                className={OUTLINE_BUTTON}
                onClick={() =>
                  deleteMutation.mutate(backup.id, {
                    onError: (error) => toast.error(error.message),
                  })
                }
                disabled={deleteMutation.isPending}
              >
                Delete
              </Button>
            </div>
          </div>
        ))}
      </div>

      <AlertDialog
        open={restoreTarget !== null}
        onOpenChange={(open) => {
          if (!open) setRestoreTarget(null);
        }}
      >
        <AlertDialogContent className="border-2 border-white bg-black">
          <AlertDialogHeader>
            <AlertDialogTitle className="text-white">
              Restore this backup?
            </AlertDialogTitle>
            <AlertDialogDescription className="text-gray-300">
              {restoreTarget &&
                `Your current games, categories and custom statuses are replaced by the backup from ${formatBackupDate(
                  restoreTarget.createdAt,
                )} (${backupContentSummary(restoreTarget)}). Your current state is saved as a backup first, so you can undo this.`}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel className={OUTLINE_BUTTON}>
              Cancel
            </AlertDialogCancel>
            <Button
              variant="outline"
              className={OUTLINE_BUTTON}
              onClick={handleRestore}
              disabled={restoreMutation.isPending}
            >
              {restoreMutation.isPending ? "Restoring..." : "Restore"}
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
