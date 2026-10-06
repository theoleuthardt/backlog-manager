import { useDroppable } from "@dnd-kit/core";
import { GroupSection } from "components/GroupSection";
import { statusColor } from "~/lib/statusStyle";

interface StatusGroupSectionProps<T> {
  status: string;
  items: readonly T[];
  renderItem: (item: T) => React.ReactNode;
  isCollapsed: boolean;
  onToggle: () => void;
}

/**
 * A status group that doubles as the drop target for dragging cards
 * between statuses; an empty one stays visible so it can be dropped on.
 */
export function StatusGroupSection<T>({
  status,
  items,
  renderItem,
  isCollapsed,
  onToggle,
}: StatusGroupSectionProps<T>) {
  const { setNodeRef, isOver } = useDroppable({ id: status });

  return (
    <div ref={setNodeRef}>
      <GroupSection
        label={status}
        items={items}
        renderItem={renderItem}
        color={statusColor(status)}
        isCollapsed={isCollapsed}
        onToggle={onToggle}
        isDropTarget={isOver}
        emptyHint={`Drop a game here to mark it as ${status}`}
      />
    </div>
  );
}
