import { ChevronDown, Trash2, X } from "lucide-react";
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
 * Bar pinned to the top of the dashboard column while it is in selection
 * mode, shown while the dashboard is in selection mode: the
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
    className="surface-glow bg-surface sticky top-4 z-40 flex flex-wrap items-center justify-center gap-2 self-center rounded-2xl border-2 border-white px-4 py-3"
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
          <ChevronDown className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="center">
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
