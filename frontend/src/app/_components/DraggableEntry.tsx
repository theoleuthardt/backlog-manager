"use client";
import { useDraggable } from "@dnd-kit/core";

/**
 * Makes a dashboard card draggable between status groups. The pointer
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

  return (
    <div
      ref={setNodeRef}
      {...listeners}
      className={`transition-opacity ${isDragging ? "opacity-30" : ""}`}
    >
      {children}
    </div>
  );
};
