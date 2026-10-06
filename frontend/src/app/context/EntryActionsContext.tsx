import { createContext, useContext } from "react";

export interface EntryRef {
  id: number;
  title: string;
  status?: string;
}

export interface CategoryRef {
  id: number;
  name: string;
}

export interface EntryActions {
  openEntry: (id: number) => void;
  selectionMode: boolean;
  selectedIds: ReadonlySet<number>;
  toggleSelected: (id: number) => void;
  startSelection: (id: number) => void;
  requestDelete: (entries: readonly EntryRef[]) => void;
  changeStatus: (entry: EntryRef, status: string) => void;
  statusOptions: readonly string[];
  categories: readonly CategoryRef[];
  categoriesByEntry: ReadonlyMap<number, readonly CategoryRef[]>;
  toggleCategory: (
    entryId: number,
    categoryId: number,
    assigned: boolean,
  ) => void;
}

const EntryActionsContext = createContext<EntryActions | null>(null);

/**
 * What an entry tile can do on the dashboard (open its dialog, take
 * part in a selection, show its context menu). The dashboard owns the
 * state - in particular the one entry dialog, so an entry that moves to
 * another group while it is open (e.g. after adding a category) does not
 * lose the dialog - and hands it to the tiles through this context so
 * the memoised tiles need no callback props.
 */
export const EntryActionsProvider = EntryActionsContext.Provider;

export function useEntryActions(): EntryActions {
  const context = useContext(EntryActionsContext);
  if (!context) {
    throw new Error("useEntryActions must be used within EntryActionsProvider");
  }
  return context;
}
