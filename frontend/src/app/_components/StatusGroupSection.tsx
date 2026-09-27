"use client";
import { useDroppable } from "@dnd-kit/core";
import { GroupSection } from "components/GroupSection";
import { statusColor } from "~/lib/statusStyle";

interface StatusGroupSectionProps {
  status: string;
  count: number;
  isCollapsed: boolean;
  onToggle: () => void;
  children: React.ReactNode;
}

/**
 * A status group that doubles as the drop target for dragging cards
 * between statuses; an empty one stays visible so it can be dropped on.
 */
export const StatusGroupSection = ({
  status,
  count,
  isCollapsed,
  onToggle,
  children,
}: StatusGroupSectionProps) => {
  const { setNodeRef, isOver } = useDroppable({ id: status });

  return (
    <div ref={setNodeRef}>
      <GroupSection
        label={status}
        count={count}
        color={statusColor(status)}
        isCollapsed={isCollapsed}
        onToggle={onToggle}
        isDropTarget={isOver}
        emptyHint={`Drop a game here to mark it as ${status}`}
      >
        {children}
      </GroupSection>
    </div>
  );
};
