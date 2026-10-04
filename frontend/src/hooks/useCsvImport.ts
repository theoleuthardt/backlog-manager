import { useCallback, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import * as csvApi from "~/lib/api/csv";
import type {
  ColumnConfig,
  CsvImportProgress,
  SubmitCsvEntry,
} from "~/lib/api/csv";

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
  const abortControllerRef = useRef<AbortController | null>(null);

  const run = useCallback(async (content: string, config: ColumnConfig) => {
    const controller = new AbortController();
    abortControllerRef.current = controller;
    setIsRunning(true);
    setProgress(null);
    try {
      return await csvApi.previewCsvStream(
        content,
        config,
        setProgress,
        controller.signal,
      );
    } finally {
      abortControllerRef.current = null;
      setIsRunning(false);
      setProgress(null);
    }
  }, []);

  const cancel = useCallback(() => {
    abortControllerRef.current?.abort();
  }, []);

  return { run, cancel, isRunning, progress };
}

export function useCsvSubmitStream() {
  const queryClient = useQueryClient();
  const [isRunning, setIsRunning] = useState(false);
  const [progress, setProgress] = useState<CsvImportProgress | null>(null);
  const abortControllerRef = useRef<AbortController | null>(null);

  const run = useCallback(
    async (entries: SubmitCsvEntry[]) => {
      const controller = new AbortController();
      abortControllerRef.current = controller;
      setIsRunning(true);
      setProgress(null);
      try {
        return await csvApi.submitCsvStream(
          entries,
          setProgress,
          controller.signal,
        );
      } finally {
        await queryClient.invalidateQueries({ queryKey: ["backlog-entries"] });
        abortControllerRef.current = null;
        setIsRunning(false);
        setProgress(null);
      }
    },
    [queryClient],
  );

  const cancel = useCallback(() => {
    abortControllerRef.current?.abort();
  }, []);

  return { run, cancel, isRunning, progress };
}
