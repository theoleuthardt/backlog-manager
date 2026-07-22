"use client";
import React, { useState } from "react";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";
import { toast } from "sonner";
import { api } from "~/trpc/react";
import type { BacklogEntry } from "~/server/db/utils/mapper";

export const ExportCSVContent = () => {
  const [isExporting, setIsExporting] = useState(false);
  const [progress, setProgress] = useState(0);
  const [totalEntries, setTotalEntries] = useState(0);
  const [processedEntries, setProcessedEntries] = useState(0);
  const [completionMessage, setCompletionMessage] = useState("");

  const exportQuery = api.csv.exportEntries.useQuery(undefined, {
    enabled: false,
  });

  const convertToCSV = (data: BacklogEntry[]) => {
    if (data.length === 0) return "";

    // Create CSV rows
    const rows = data.map((entry) => {
      return [
        `"${(entry.title ?? "").replace(/"/g, '""')}"`,
        `"${(entry.genre ?? "").replace(/"/g, '""')}"`,
        `"${(entry.platform ?? "").replace(/"/g, '""')}"`,
        `"${(entry.status ?? "").replace(/"/g, '""')}"`,
        entry.owned ? "true" : "false",
        entry.interest ?? "",
        entry.reviewStars ?? "",
        `"${(entry.review ?? "").replace(/"/g, '""')}"`,
        `"${(entry.note ?? "").replace(/"/g, '""')}"`,
        entry.mainTime ?? "",
        entry.mainPlusExtraTime ?? "",
        entry.completionTime ?? "",
        `"${(entry.imageLink ?? "").replace(/"/g, '""')}"`,
      ].join(",");
    });

    return rows.join("\n");
  };

  const downloadCSV = (csvContent: string, filename: string) => {
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    const url = URL.createObjectURL(blob);

    link.setAttribute("href", url);
    link.setAttribute("download", filename);
    link.style.visibility = "hidden";

    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleExport = async () => {
    try {
      setIsExporting(true);
      setProgress(0);
      setProcessedEntries(0);
      setCompletionMessage("");

      toast.info("Fetching backlog entries...");

      const result = await exportQuery.refetch();

      if (!result.data?.success || !result.data.data) {
        throw new Error(result.data?.error ?? "Failed to fetch entries");
      }

      const entries = result.data.data;
      setTotalEntries(entries.length);

      if (entries.length === 0) {
        toast.warning("No backlog entries found to export");
        setCompletionMessage("No entries to export");
        setIsExporting(false);
        return;
      }

      toast.info(`Processing ${entries.length} entries...`);

      const progressInterval = setInterval(() => {
        setProcessedEntries((prev) => {
          const next = Math.min(prev + 1, entries.length);
          setProgress((next / entries.length) * 100);
          return next;
        });
      }, 10);

      const csvContent = convertToCSV(entries);

      await new Promise((resolve) => setTimeout(resolve, entries.length * 10 + 100));
      clearInterval(progressInterval);

      setProcessedEntries(entries.length);
      setProgress(100);

      const timestamp = new Date().toISOString().split("T")[0];
      const filename = `backlog-export-${timestamp}.csv`;
      downloadCSV(csvContent, filename);

      toast.success(`Successfully exported ${entries.length} entries!`);
      setCompletionMessage(`✓ Successfully exported ${entries.length} backlog entries!`);
    } catch (error) {
      console.error("Export error:", error);
      toast.error(error instanceof Error ? error.message : "Failed to export entries");
      setCompletionMessage("Export failed. Please try again.");
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <div className="flex flex-col items-center justify-center gap-8 py-12">
      <div className="flex flex-col items-center gap-4">
        <Image
          src="/csv_export.png"
          alt="export CSV"
          width={64}
          height={64}
        />
        <h1 className="text-3xl font-bold">Export Backlog to CSV</h1>
        <p className="max-w-md text-center text-gray-400">
          Export all your backlog entries to a CSV file
        </p>
      </div>

      <Button
        className="border-2 border-white font-bold text-white bg-black hover:bg-white hover:text-black"
        variant="outline"
        onClick={() => void handleExport()}
        disabled={isExporting}
        size="lg"
      >
        {isExporting ? "Exporting..." : "Export to CSV"}
      </Button>

      {isExporting && totalEntries > 0 && (
        <div className="w-full max-w-md space-y-2">
          <div className="h-2 bg-white/20 rounded-full overflow-hidden">
            <div
              className="h-full bg-white transition-all duration-300"
              style={{
                width: `${progress}%`,
              }}
            />
          </div>
          <p className="text-center text-gray-400 text-sm">
            Processing entries: {processedEntries} / {totalEntries}
          </p>
        </div>
      )}

      {completionMessage && (
        <div className="w-full max-w-md text-center text-white">
          {completionMessage}
        </div>
      )}
    </div>
  );
};
