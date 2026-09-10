"use client";
import React, { useRef, useEffect, useCallback } from "react";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";
import { toast } from "sonner";
import { v4 as uuidv4 } from "uuid";
import {
  useImportCsv,
  useImportProgress,
  useCancelCsvImport,
} from "~/hooks/useCsvImport";
import type { ImportResult } from "~/lib/api/csv";
import { MissingGamesModal } from "./MissingGamesModal";
import { useCSVImport } from "~/app/context/CSVImportContext";

const COLUMN_OPTIONS = [
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z",
];

/**
 * The backend import request keeps running after a cancel is sent (it
 * only checks the cancel flag between records) - `cancelledSessionIdRef`
 * tracks which session_id was cancelled so its eventual settlement
 * doesn't overwrite the cancellation message with a stale success/error
 * result.
 */
export const ImportCSVContent = () => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const cancelledSessionIdRef = useRef<string | null>(null);
  const csvImport = useCSVImport();
  const {
    state,
    startImport,
    updateProgress,
    completeImport,
    setColumnConfig,
    setMissingGamesModal,
    showCancelConfirmation,
    cancelImport,
  } = csvImport;
  const {
    isLoading,
    totalRecords,
    createdRecords,
    completionMessage,
    missingGames,
    showMissingGamesModal,
    showCancelConfirmation: showConfirm,
    titleColumn,
    genreColumn,
    platformColumn,
    statusColumn,
    sessionId,
  } = state;

  const importCSV = useImportCsv();

  const handleImportComplete = (result: ImportResult) => {
    const { success, failed, errors, missingGames: missing } = result;
    console.log(
      `CSV import completed: ${success} successful, ${failed} failed, ${missing.length} missing`,
    );

    if (missing.length > 0) {
      toast.info(
        `${success} entries imported. ${missing.length} games need manual lookup.`,
      );
      completeImport(
        `✓ ${success} entries created successfully. ${missing.length} needed manual lookup.`,
        missing,
      );
    } else if (errors.length > 0) {
      console.error("Import errors:", errors);
      const message =
        failed > 0
          ? `Import completed: ${success} created, ${failed} failed`
          : `Successfully imported ${success} backlog entries!`;
      toast.warning(message);
      completeImport(`✓ ${message}`);
    } else {
      const message = `Successfully imported ${success} backlog entries!`;
      toast.success(message);
      completeImport(`✓ ${message}`);
    }
  };

  const handleButtonClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      void processCSVFile(file);
    }
  };

  const getProgress = useImportProgress(sessionId, isLoading);

  useEffect(() => {
    if (getProgress.data !== undefined) {
      updateProgress(getProgress.data);
    }
  }, [getProgress.data, updateProgress]);

  const cancelCSVMutation = useCancelCsvImport();

  const handleCancelImport = useCallback(async () => {
    if (sessionId) {
      try {
        cancelledSessionIdRef.current = sessionId;
        await cancelCSVMutation.mutateAsync(sessionId);
        toast.info("Import cancelled");
        completeImport("Import was cancelled by the user");
        cancelImport();
      } catch (error) {
        cancelledSessionIdRef.current = null;
        toast.error(
          error instanceof Error ? error.message : "Failed to cancel import",
        );
      }
    }
  }, [sessionId, cancelCSVMutation, cancelImport, completeImport]);

  const processCSVFile = async (file: File) => {
    let newSessionId = "";
    try {
      const fileContent = await file.text();
      const lines = fileContent.trim().split("\n");
      const recordCount = Math.max(0, lines.length - 1);

      newSessionId = uuidv4();
      startImport(newSessionId, recordCount);

      const result = await importCSV.mutateAsync({
        content: fileContent,
        titleColumn,
        genreColumn,
        platformColumn,
        statusColumn,
        sessionId: newSessionId,
      });
      if (cancelledSessionIdRef.current !== newSessionId) {
        handleImportComplete(result);
      }
    } catch (error) {
      if (cancelledSessionIdRef.current !== newSessionId) {
        toast.error(
          error instanceof Error ? error.message : "Error processing CSV file",
        );
        completeImport("");
      }
    }
  };

  return (
    <div className="flex flex-col items-center justify-center gap-8 py-12">
      <div className="flex flex-col items-center gap-4">
        <Image src="/csv_import.png" alt="import CSV" width={64} height={64} />
        <h1 className="text-3xl font-bold">Import Backlog from CSV</h1>
        <p className="max-w-md text-center text-gray-400">
          Select a CSV file to import your game backlog entries
        </p>
      </div>

      <div className="grid w-full max-w-md grid-cols-2 gap-4">
        <div className="flex flex-col gap-2">
          <label className="text-sm font-medium text-white">Title Column</label>
          <select
            value={titleColumn}
            onChange={(e) =>
              setColumnConfig(
                e.target.value,
                genreColumn,
                platformColumn,
                statusColumn,
              )
            }
            className="rounded border-2 border-white bg-black px-3 py-2 text-white"
          >
            {COLUMN_OPTIONS.map((col) => (
              <option key={col} value={col}>
                {col}
              </option>
            ))}
          </select>
        </div>

        <div className="flex flex-col gap-2">
          <label className="text-sm font-medium text-white">Genre Column</label>
          <select
            value={genreColumn}
            onChange={(e) =>
              setColumnConfig(
                titleColumn,
                e.target.value,
                platformColumn,
                statusColumn,
              )
            }
            className="rounded border-2 border-white bg-black px-3 py-2 text-white"
          >
            {COLUMN_OPTIONS.map((col) => (
              <option key={col} value={col}>
                {col}
              </option>
            ))}
          </select>
        </div>

        <div className="flex flex-col gap-2">
          <label className="text-sm font-medium text-white">
            Platform Column
          </label>
          <select
            value={platformColumn}
            onChange={(e) =>
              setColumnConfig(
                titleColumn,
                genreColumn,
                e.target.value,
                statusColumn,
              )
            }
            className="rounded border-2 border-white bg-black px-3 py-2 text-white"
          >
            {COLUMN_OPTIONS.map((col) => (
              <option key={col} value={col}>
                {col}
              </option>
            ))}
          </select>
        </div>

        <div className="flex flex-col gap-2">
          <label className="text-sm font-medium text-white">
            Status Column
          </label>
          <select
            value={statusColumn}
            onChange={(e) =>
              setColumnConfig(
                titleColumn,
                genreColumn,
                platformColumn,
                e.target.value,
              )
            }
            className="rounded border-2 border-white bg-black px-3 py-2 text-white"
          >
            {COLUMN_OPTIONS.map((col) => (
              <option key={col} value={col}>
                {col}
              </option>
            ))}
          </select>
        </div>
      </div>

      <Button
        className="border-2 border-white bg-black font-bold text-white hover:bg-white hover:text-black"
        variant="outline"
        onClick={handleButtonClick}
        disabled={isLoading}
        size="lg"
      >
        Select CSV File
      </Button>

      {isLoading && totalRecords > 0 && (
        <div className="w-full max-w-md space-y-2">
          <div className="h-2 overflow-hidden rounded-full bg-white/20">
            <div
              className="h-full bg-white transition-all duration-300"
              style={{
                width: `${(createdRecords / totalRecords) * 100}%`,
              }}
            />
          </div>
          <p className="text-center text-sm text-gray-400">
            Creating entries: {createdRecords} / {totalRecords}
          </p>
          <Button
            className="w-full border-2 border-red-500 bg-black font-bold text-red-500 hover:bg-red-500 hover:text-black"
            variant="outline"
            onClick={() => void showCancelConfirmation(true)}
            size="sm"
          >
            Cancel Import
          </Button>
        </div>
      )}

      {showConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="mx-4 w-full max-w-sm space-y-4 rounded-lg border-2 border-white bg-black p-6">
            <h2 className="text-xl font-bold text-white">Cancel Import?</h2>
            <p className="text-gray-400">
              Are you sure you want to cancel the import? The process will stop
              and no further entries will be created.
            </p>
            <div className="flex justify-end gap-4">
              <Button
                className="border-2 border-white bg-black font-bold text-white hover:bg-white hover:text-black"
                variant="outline"
                onClick={() => showCancelConfirmation(false)}
              >
                Keep Importing
              </Button>
              <Button
                className="border-2 border-red-500 bg-black font-bold text-red-500 hover:bg-red-500 hover:text-black"
                variant="outline"
                onClick={handleCancelImport}
              >
                Yes, Cancel
              </Button>
            </div>
          </div>
        </div>
      )}

      <input
        ref={fileInputRef}
        type="file"
        accept=".csv"
        className="hidden"
        onChange={handleFileChange}
      />

      {completionMessage && (
        <div className="w-full max-w-md text-center text-white">
          {completionMessage}
        </div>
      )}

      <MissingGamesModal
        missingGames={missingGames}
        isOpen={showMissingGamesModal}
        onClose={() => setMissingGamesModal(false)}
        onGameSelected={(gameTitle, gameData) => {
          console.log(`Selected game for "${gameTitle}":`, gameData);
        }}
      />
    </div>
  );
};
