import { memo } from "react";
import { useDraggable } from "@dnd-kit/core";
import { BacklogEntry } from "components/BacklogEntry";
import type { BacklogEntryData } from "~/lib/api/backlog";

/**
 * Makes a dashboard card draggable between status groups. It receives the
 * entry rather than children so memo can skip re-rendering every card
 * while the rest of the dashboard updates. Events from
 * the entry dialog are portaled out of the card in the DOM but still
 * bubble to it through React, so only events whose target is inside the
 * card itself may start a drag. The pointer
 * and touch sensors in DashboardContent only start a drag after a
 * small movement or press delay, so a plain click still opens the
 * entry dialog and touch scrolling keeps working.
 */
export const DraggableEntry = memo(function DraggableEntry({
  entry,
}: {
  entry: BacklogEntryData;
}) {
  const { setNodeRef, listeners, isDragging } = useDraggable({ id: entry.id });

  const ownListeners = Object.fromEntries(
    Object.entries(listeners ?? {}).map(([name, handler]) => [
      name,
      (event: React.SyntheticEvent) => {
        if (!event.currentTarget.contains(event.target as Node)) return;
        (handler as (event: React.SyntheticEvent) => void)(event);
      },
    ]),
  );

  return (
    <div
      ref={setNodeRef}
      {...ownListeners}
      className={`transition-opacity ${isDragging ? "opacity-30" : ""}`}
    >
      <BacklogEntry {...entry} />
    </div>
  );
});
