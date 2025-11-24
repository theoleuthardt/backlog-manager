"use client";
import React, { useRef, useEffect, useCallback } from "react";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";
import { toast } from "sonner";
import { v4 as uuidv4 } from "uuid";
import { api } from "~/trpc/react";
import { MissingGamesModal } from "./MissingGamesModal";
import { useCSVImport } from "~/app/context/CSVImportContext";

const COLUMN_OPTIONS = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"];

export const ImportCSVContent = () => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const csvImport = useCSVImport();
  const { state, startImport, updateProgress, completeImport, setColumnConfig, setMissingGamesModal, showCancelConfirmation, cancelImport } = csvImport;
  const { isLoading, totalRecords, createdRecords, completionMessage, missingGames, showMissingGamesModal, showCancelConfirmation: showConfirm, titleColumn, genreColumn, platformColumn, statusColumn, sessionId } = state;

  const importCSV = api.csv.importEntries.useMutation({
    onSuccess: (result) => {
      if (result.success && result.data) {
        const { success, failed, errors, missingGames: missing } = result.data;
        console.log(`CSV import completed: ${success} successful, ${failed} failed, ${missing.length} missing`);

        if (missing && missing.length > 0) {
          toast.info(
            `${success} entries imported. ${missing.length} games need manual lookup.`
          );
          completeImport(
            `✓ ${success} entries created successfully. ${missing.length} needed manual lookup.`,
            missing
          );
        } else if (errors.length > 0) {
          console.error("Import errors:", errors);
          const message = failed > 0
            ? `Import completed: ${success} created, ${failed} failed`
            : `Successfully imported ${success} backlog entries!`;
          toast.warning(message);
          completeImport(`✓ ${message}`);
        } else {
          const message = `Successfully imported ${success} backlog entries!`;
          toast.success(message);
          completeImport(`✓ ${message}`);
        }
      } else {
        toast.error(result.error ?? "Import failed");
        completeImport("");
      }
    },
    onError: (err) => {
      toast.error(err.message || "Failed to import CSV");
      completeImport("");
    },
  });

  const handleButtonClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      void processCSVFile(file);
    }
  };

  const getProgress = api.csv.getProgress.useQuery(
    { sessionId: sessionId ?? "" },
    { enabled: sessionId !== null && isLoading, refetchInterval: 200 }
  );

  // Update createdRecords when progress changes
  useEffect(() => {
    if (getProgress.data) {
      updateProgress(getProgress.data.processed);
    }
  }, [getProgress.data, updateProgress]);

  const cancelCSVMutation = api.csv.cancelImport.useMutation({
    onSuccess: () => {
      toast.info("Import cancelled");
      completeImport("Import was cancelled by the user");
    },
    onError: (err) => {
      toast.error(err.message || "Failed to cancel import");
    },
  });

  const handleCancelImport = useCallback(async () => {
    if (sessionId) {
      try {
        await cancelCSVMutation.mutateAsync({ sessionId });
        cancelImport();
      } catch (error) {
        console.error("Failed to cancel import:", error);
      }
    }
  }, [sessionId, cancelCSVMutation, cancelImport]);

  const processCSVFile = async (file: File) => {
    try {
      const fileContent = await file.text();
      const lines = fileContent.trim().split('\n');
      const recordCount = Math.max(0, lines.length - 1);

      // Generate session ID for progress tracking
      const newSessionId = uuidv4();
      startImport(newSessionId, recordCount);

      await importCSV.mutateAsync({
        content: fileContent,
        titleColumn,
        genreColumn,
        platformColumn,
        statusColumn,
        sessionId: newSessionId,
      });
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Error processing CSV file");
      completeImport("");
    }
  };

  return (
    <div className="flex flex-col items-center justify-center gap-8 py-12">
      <div className="flex flex-col items-center gap-4">
        <Image
          src="/csv_import.png"
          alt="import CSV"
          width={64}
          height={64}
        />
        <h1 className="text-3xl font-bold">Import Backlog from CSV</h1>
        <p className="max-w-md text-center text-gray-400">
          Select a CSV file to import your game backlog entries
        </p>
      </div>

      <div className="w-full max-w-md grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-2">
          <label className="text-sm font-medium text-white">Title Column</label>
          <select
            value={titleColumn}
            onChange={(e) => setColumnConfig(e.target.value, genreColumn, platformColumn, statusColumn)}
            className="px-3 py-2 bg-black border-2 border-white text-white rounded"
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
            onChange={(e) => setColumnConfig(titleColumn, e.target.value, platformColumn, statusColumn)}
            className="px-3 py-2 bg-black border-2 border-white text-white rounded"
          >
            {COLUMN_OPTIONS.map((col) => (
              <option key={col} value={col}>
                {col}
              </option>
            ))}
          </select>
        </div>

        <div className="flex flex-col gap-2">
          <label className="text-sm font-medium text-white">Platform Column</label>
          <select
            value={platformColumn}
            onChange={(e) => setColumnConfig(titleColumn, genreColumn, e.target.value, statusColumn)}
            className="px-3 py-2 bg-black border-2 border-white text-white rounded"
          >
            {COLUMN_OPTIONS.map((col) => (
              <option key={col} value={col}>
                {col}
              </option>
            ))}
          </select>
        </div>

        <div className="flex flex-col gap-2">
          <label className="text-sm font-medium text-white">Status Column</label>
          <select
            value={statusColumn}
            onChange={(e) => setColumnConfig(titleColumn, genreColumn, platformColumn, e.target.value)}
            className="px-3 py-2 bg-black border-2 border-white text-white rounded"
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
        className="border-2 border-white font-bold text-white bg-black hover:bg-white hover:text-black"
        variant="outline"
        onClick={handleButtonClick}
        disabled={isLoading}
        size="lg"
      >
        Select CSV File
      </Button>

      {isLoading && totalRecords > 0 && (
        <div className="w-full max-w-md space-y-2">
          <div className="h-2 bg-white/20 rounded-full overflow-hidden">
            <div
              className="h-full bg-white transition-all duration-300"
              style={{
                width: `${(createdRecords / totalRecords) * 100}%`
              }}
            />
          </div>
          <p className="text-center text-gray-400 text-sm">
            Creating entries: {createdRecords} / {totalRecords}
          </p>
          <Button
            className="w-full border-2 border-red-500 font-bold text-red-500 bg-black hover:bg-red-500 hover:text-black"
            variant="outline"
            onClick={() => void showCancelConfirmation(true)}
            size="sm"
          >
            Cancel Import
          </Button>
        </div>
      )}

      {showConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-black border-2 border-white rounded-lg p-6 max-w-sm w-full mx-4 space-y-4">
            <h2 className="text-xl font-bold text-white">Cancel Import?</h2>
            <p className="text-gray-400">
              Are you sure you want to cancel the import? The process will stop and no further entries will be created.
            </p>
            <div className="flex gap-4 justify-end">
              <Button
                className="border-2 border-white font-bold text-white bg-black hover:bg-white hover:text-black"
                variant="outline"
                onClick={() => showCancelConfirmation(false)}
              >
                Keep Importing
              </Button>
              <Button
                className="border-2 border-red-500 font-bold text-red-500 bg-black hover:bg-red-500 hover:text-black"
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

