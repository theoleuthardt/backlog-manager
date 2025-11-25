"use client";

import React, { createContext, useContext, useState, useCallback } from "react";
import type { MissingGame } from "~/server/csv/parseCSV";

export interface ImportState {
  isLoading: boolean;
  isCancelling: boolean;
  sessionId: string | null;
  totalRecords: number;
  createdRecords: number;
  completionMessage: string | null;
  missingGames: MissingGame[];
  showMissingGamesModal: boolean;
  showCancelConfirmation: boolean;
  titleColumn: string;
  genreColumn: string;
  platformColumn: string;
  statusColumn: string;
}

interface CSVImportContextType {
  state: ImportState;
  startImport: (sessionId: string, totalRecords: number) => void;
  updateProgress: (createdRecords: number) => void;
  completeImport: (
    completionMessage: string,
    missingGames?: MissingGame[]
  ) => void;
  resetImport: () => void;
  setMissingGamesModal: (show: boolean) => void;
  setColumnConfig: (
    titleColumn: string,
    genreColumn: string,
    platformColumn: string,
    statusColumn: string
  ) => void;
  showCancelConfirmation: (show: boolean) => void;
  cancelImport: () => void;
}

const CSVImportContext = createContext<CSVImportContextType | undefined>(
  undefined
);

const DEFAULT_STATE: ImportState = {
  isLoading: false,
  isCancelling: false,
  sessionId: null,
  totalRecords: 0,
  createdRecords: 0,
  completionMessage: null,
  missingGames: [],
  showMissingGamesModal: false,
  showCancelConfirmation: false,
  titleColumn: "A",
  genreColumn: "B",
  platformColumn: "C",
  statusColumn: "D",
};

export const CSVImportProvider: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const [state, setState] = useState<ImportState>(DEFAULT_STATE);

  const startImport = useCallback(
    (sessionId: string, totalRecords: number) => {
      setState((prev) => ({
        ...prev,
        isLoading: true,
        sessionId,
        totalRecords,
        createdRecords: 0,
        completionMessage: null,
        missingGames: [],
      }));
    },
    []
  );

  const updateProgress = useCallback((createdRecords: number) => {
    setState((prev) => ({
      ...prev,
      createdRecords,
    }));
  }, []);

  const completeImport = useCallback(
    (completionMessage: string, missingGames?: MissingGame[]) => {
      setState((prev) => ({
        ...prev,
        isLoading: false,
        completionMessage,
        missingGames: missingGames ?? [],
        showMissingGamesModal: (missingGames?.length ?? 0) > 0,
      }));
    },
    []
  );

  const resetImport = useCallback(() => {
    setState(DEFAULT_STATE);
  }, []);

  const setMissingGamesModal = useCallback((show: boolean) => {
    setState((prev) => ({
      ...prev,
      showMissingGamesModal: show,
    }));
  }, []);

  const setColumnConfig = useCallback(
    (
      titleColumn: string,
      genreColumn: string,
      platformColumn: string,
      statusColumn: string
    ) => {
      setState((prev) => ({
        ...prev,
        titleColumn,
        genreColumn,
        platformColumn,
        statusColumn,
      }));
    },
    []
  );

  const showCancelConfirmation = useCallback((show: boolean) => {
    setState((prev) => ({
      ...prev,
      showCancelConfirmation: show,
    }));
  }, []);

  const cancelImport = useCallback(() => {
    setState((prev) => ({
      ...prev,
      isCancelling: true,
      showCancelConfirmation: false,
    }));
  }, []);

  return (
    <CSVImportContext.Provider
      value={{
        state,
        startImport,
        updateProgress,
        completeImport,
        resetImport,
        setMissingGamesModal,
        setColumnConfig,
        showCancelConfirmation,
        cancelImport,
      }}
    >
      {children}
    </CSVImportContext.Provider>
  );
};

export const useCSVImport = (): CSVImportContextType => {
  const context = useContext(CSVImportContext);
  if (context === undefined) {
    throw new Error("useCSVImport must be used within CSVImportProvider");
  }
  return context;
};