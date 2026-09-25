"use client";
import { useDraggable } from "@dnd-kit/core";

/**
 * Makes a dashboard card draggable between status groups. Events from
 * the entry dialog are portaled out of the card in the DOM but still
 * bubble to it through React, so only events whose target is inside the
 * card itself may start a drag. The pointer
 * and touch sensors in DashboardContent only start a drag after a
 * small movement or press delay, so a plain click still opens the
 * entry dialog and touch scrolling keeps working.
 */
export const DraggableEntry = ({
  entryId,
  children,
}: {
  entryId: number;
  children: React.ReactNode;
}) => {
  const { setNodeRef, listeners, isDragging } = useDraggable({ id: entryId });

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
      {children}
    </div>
  );
};
