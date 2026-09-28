import { useCallback, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import * as csvApi from "~/lib/api/csv";
import type { ColumnConfig, CsvImportProgress, SubmitCsvEntry } from "~/lib/api/csv";

export function useCsvHeaders() {
  const [isLoading, setIsLoading] = useState(false);

  const run = useCallback(async (content: string) => {
    setIsLoading(true);
    try {
      return await csvApi.getCsvHeaders(content);
    } finally {
      setIsLoading(false);
    }
  }, []);

  return { run, isLoading };
}

export function useCsvPreviewStream() {
  const [isRunning, setIsRunning] = useState(false);
  const [progress, setProgress] = useState<CsvImportProgress | null>(null);

  const run = useCallback(async (content: string, config: ColumnConfig) => {
    setIsRunning(true);
    setProgress(null);
    try {
      return await csvApi.previewCsvStream(content, config, setProgress);
    } finally {
      setIsRunning(false);
      setProgress(null);
    }
  }, []);

  return { run, isRunning, progress };
}

export function useCsvSubmitStream() {
  const queryClient = useQueryClient();
  const [isRunning, setIsRunning] = useState(false);
  const [progress, setProgress] = useState<CsvImportProgress | null>(null);

  const run = useCallback(
    async (entries: SubmitCsvEntry[]) => {
      setIsRunning(true);
      setProgress(null);
      try {
        const created = await csvApi.submitCsvStream(entries, setProgress);
        await queryClient.invalidateQueries({ queryKey: ["backlog-entries"] });
        return created;
      } finally {
        setIsRunning(false);
        setProgress(null);
      }
    },
    [queryClient],
  );

  return { run, isRunning, progress };
}
