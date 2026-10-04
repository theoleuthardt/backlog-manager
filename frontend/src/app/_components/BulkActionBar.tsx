"use client";
import { ChevronUp, Trash2, X } from "lucide-react";
import { Button } from "shadcn_components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "shadcn_components/ui/dropdown-menu";

interface BulkActionBarProps {
  selectedCount: number;
  visibleCount: number;
  statusOptions: readonly string[];
  isBusy: boolean;
  onSelectAllVisible: () => void;
  onClearSelection: () => void;
  onSetStatus: (status: string) => void;
  onDelete: () => void;
  onDone: () => void;
}

/**
 * Floating bar shown while the dashboard is in selection mode: the
 * number of selected games, select-all/clear shortcuts and the bulk
 * actions (change status, delete) that apply to the selection.
 */
export const BulkActionBar = ({
  selectedCount,
  visibleCount,
  statusOptions,
  isBusy,
  onSelectAllVisible,
  onClearSelection,
  onSetStatus,
  onDelete,
  onDone,
}: BulkActionBarProps) => (
  <div
    role="toolbar"
    aria-label="Bulk actions"
    className="surface-glow bg-surface fixed bottom-4 left-1/2 z-40 flex max-w-[calc(100vw-2rem)] -translate-x-1/2 flex-wrap items-center justify-center gap-2 rounded-2xl border-2 border-white px-4 py-3"
  >
    <span className="text-sm font-semibold" aria-live="polite">
      {selectedCount} selected
    </span>
    <Button
      type="button"
      variant="ghost"
      size="sm"
      onClick={onSelectAllVisible}
      disabled={isBusy || selectedCount === visibleCount}
    >
      Select all {visibleCount}
    </Button>
    <Button
      type="button"
      variant="ghost"
      size="sm"
      onClick={onClearSelection}
      disabled={isBusy || selectedCount === 0}
    >
      Clear
    </Button>
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          type="button"
          variant="outline"
          size="sm"
          disabled={isBusy || selectedCount === 0}
          className="gap-1.5"
        >
          Set status
          <ChevronUp className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="center" side="top">
        {statusOptions.map((status) => (
          <DropdownMenuItem key={status} onSelect={() => onSetStatus(status)}>
            {status}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
    <Button
      type="button"
      variant="destructive"
      size="sm"
      onClick={onDelete}
      disabled={isBusy || selectedCount === 0}
      className="gap-1.5"
    >
      <Trash2 className="h-4 w-4" />
      Delete
    </Button>
    <Button
      type="button"
      variant="outline"
      size="sm"
      onClick={onDone}
      disabled={isBusy}
      className="gap-1.5"
    >
      <X className="h-4 w-4" />
      Done
    </Button>
  </div>
);
