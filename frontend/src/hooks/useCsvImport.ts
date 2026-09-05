import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as csvApi from "~/lib/api/csv";
import { createEntry } from "~/lib/api/backlog";

export function useImportCsv() {
  return useMutation({
    mutationFn: csvApi.importCsv,
  });
}

export function useImportProgress(sessionId: string | null, enabled: boolean) {
  return useQuery({
    queryKey: ["csv-import-progress", sessionId],
    queryFn: () => csvApi.getImportProgress(sessionId ?? ""),
    enabled: sessionId !== null && enabled,
    refetchInterval: 200,
  });
}

export function useCancelCsvImport() {
  return useMutation({
    mutationFn: csvApi.cancelImport,
  });
}

export function useCreateMissingGameEntry() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      genre: string;
      platform: string;
      imageLink: string | null;
      mainTime: number;
      mainPlusExtraTime: number;
      completionTime: number;
      title: string;
    }) => {
      return createEntry({
        title: input.title,
        genre: input.genre
          .split(",")
          .map((g) => g.trim())
          .filter(Boolean),
        platform: input.platform
          .split(",")
          .map((p) => p.trim())
          .filter(Boolean),
        status: "Not Started",
        owned: true,
        interest: 5,
        imageLink: input.imageLink ?? undefined,
        mainTime: input.mainTime,
        mainPlusExtraTime: input.mainPlusExtraTime,
        completionTime: input.completionTime,
      });
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["backlog-entries"] });
    },
  });
}
