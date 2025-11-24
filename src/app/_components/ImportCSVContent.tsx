"use client";
import React, { useRef, useState } from "react";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";
import { toast } from "sonner";
import { api } from "~/trpc/react";
import { MissingGamesModal } from "./MissingGamesModal";
import type { MissingGame } from "~/server/csv/parseCSV";

const COLUMN_OPTIONS = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"];

export const ImportCSVContent = () => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [completionMessage, setCompletionMessage] = useState<string | null>(null);
  const [titleColumn, setTitleColumn] = useState("A");
  const [genreColumn, setGenreColumn] = useState("B");
  const [platformColumn, setPlatformColumn] = useState("C");
  const [statusColumn, setStatusColumn] = useState("D");
  const [missingGames, setMissingGames] = useState<MissingGame[]>([]);
  const [showMissingGamesModal, setShowMissingGamesModal] = useState(false);

  const importCSV = api.csv.importEntries.useMutation({
    onSuccess: (result) => {
      if (result.success && result.data) {
        const { success, failed, errors, missingGames: missing } = result.data;
        console.log(`CSV import completed: ${success} successful, ${failed} failed, ${missing.length} missing`);

        if (missing && missing.length > 0) {
          setMissingGames(missing);
          setShowMissingGamesModal(true);
          toast.info(
            `${success} entries imported. ${missing.length} games need manual lookup.`
          );
          setCompletionMessage(
            `✓ ${success + missing.length} entries created successfully. ${missing.length} needed manual lookup.`
          );
        } else if (errors.length > 0) {
          console.error("Import errors:", errors);
          const message = failed > 0
            ? `Import completed: ${success} created, ${failed} failed`
            : `Successfully imported ${success} backlog entries!`;
          toast.warning(message);
          setCompletionMessage(`✓ ${message}`);
        } else {
          const message = `Successfully imported ${success} backlog entries!`;
          toast.success(message);
          setCompletionMessage(`✓ ${message}`);
        }
      } else {
        toast.error(result.error || "Import failed");
      }
      setIsLoading(false);
    },
    onError: (err) => {
      toast.error(err.message || "Failed to import CSV");
      setIsLoading(false);
    },
  });

  const handleButtonClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      processCSVFile(file);
    }
  };

  const processCSVFile = async (file: File) => {
    try {
      setIsLoading(true);
      const fileContent = await file.text();
      await importCSV.mutateAsync({
        content: fileContent,
        titleColumn,
        genreColumn,
        platformColumn,
        statusColumn,
      });
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Error processing CSV file");
      setIsLoading(false);
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
            onChange={(e) => setTitleColumn(e.target.value)}
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
            onChange={(e) => setGenreColumn(e.target.value)}
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
            onChange={(e) => setPlatformColumn(e.target.value)}
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
            onChange={(e) => setStatusColumn(e.target.value)}
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
        size="lg"
      >
        Select CSV File
      </Button>

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
        onClose={() => setShowMissingGamesModal(false)}
        onGameSelected={(gameTitle, gameData) => {
          console.log(`Selected game for "${gameTitle}":`, gameData);
        }}
      />
    </div>
  );
};

