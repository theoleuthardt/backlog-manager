"use client";
import { memo } from "react";
import { motion } from "motion/react";
import { Check, ExternalLink, ListChecks, Trash2 } from "lucide-react";
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuLabel,
  ContextMenuSeparator,
  ContextMenuSub,
  ContextMenuSubContent,
  ContextMenuSubTrigger,
  ContextMenuTrigger,
} from "shadcn_components/ui/context-menu";
import { EntryTile } from "components/EntryTile";
import { useEntryActions } from "~/app/context/EntryActionsContext";
import type { BacklogEntryProps } from "~/app/types";

/**
 * A dashboard card. A click opens the entry dialog, or toggles the card
 * while a selection is active; a right click shows the context menu
 * (open, select, change status, delete) without opening the dialog.
 */
export const BacklogEntry = memo(function BacklogEntry(
  props: BacklogEntryProps,
) {
  const {
    openEntry,
    selectionMode,
    selectedIds,
    toggleSelected,
    startSelection,
    requestDelete,
    changeStatus,
    statusOptions,
  } = useEntryActions();
  const isSelected = selectedIds.has(props.id);
  const entry = { id: props.id, title: props.title, status: props.status };

  const activate = () =>
    selectionMode ? toggleSelected(props.id) : openEntry(props.id);

  return (
    <ContextMenu>
      <ContextMenuTrigger asChild>
        <div
          className={`relative w-[9.375rem] cursor-pointer rounded-xl ${props.className ?? ""}`}
        >
          <motion.div
            role="button"
            tabIndex={0}
            aria-label={props.title}
            aria-pressed={selectionMode ? isSelected : undefined}
            className={`rounded-xl leading-[0] outline-none focus-visible:ring-2 focus-visible:ring-white ${isSelected ? "ring-primary ring-4" : ""}`}
            whileHover={{ scale: 1.05, y: -4 }}
            whileTap={{ scale: 0.98 }}
            transition={{ type: "spring", stiffness: 400, damping: 25 }}
            onClick={activate}
            onKeyDown={(event) => {
              if (event.key !== "Enter" && event.key !== " ") return;
              event.preventDefault();
              activate();
            }}
          >
            <EntryTile
              title={props.title}
              imageLink={props.imageLink}
              imageAlt={props.imageAlt}
              status={props.status}
              playtime={props.playtime}
              mainTime={props.mainTime}
              inSharedSpace={props.inSharedSpace}
            />
          </motion.div>
          {selectionMode && (
            <span
              aria-hidden="true"
              className={`pointer-events-none absolute top-2 left-2 flex h-6 w-6 items-center justify-center rounded-full border-2 ${isSelected ? "bg-primary text-primary-foreground border-primary" : "border-white bg-black/60"}`}
            >
              {isSelected && <Check className="h-4 w-4" />}
            </span>
          )}
        </div>
      </ContextMenuTrigger>
      <ContextMenuContent>
        <ContextMenuLabel>{props.title}</ContextMenuLabel>
        <ContextMenuSeparator />
        <ContextMenuItem onSelect={() => openEntry(props.id)}>
          <ExternalLink />
          Open details
        </ContextMenuItem>
        <ContextMenuItem onSelect={() => startSelection(props.id)}>
          <ListChecks />
          Select
        </ContextMenuItem>
        <ContextMenuSub>
          <ContextMenuSubTrigger>Move to status</ContextMenuSubTrigger>
          <ContextMenuSubContent>
            {statusOptions.map((status) => (
              <ContextMenuItem
                key={status}
                disabled={status === props.status}
                onSelect={() => changeStatus(entry, status)}
              >
                {status}
              </ContextMenuItem>
            ))}
          </ContextMenuSubContent>
        </ContextMenuSub>
        <ContextMenuSeparator />
        <ContextMenuItem
          variant="destructive"
          onSelect={() => requestDelete([entry])}
        >
          <Trash2 />
          Delete
        </ContextMenuItem>
      </ContextMenuContent>
    </ContextMenu>
  );
});
