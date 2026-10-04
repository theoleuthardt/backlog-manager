"use client";
import { useDroppable } from "@dnd-kit/core";
import { GroupSection } from "components/GroupSection";

interface CategoryGroupSectionProps<T> {
  label: string;
  items: readonly T[];
  renderItem: (item: T) => React.ReactNode;
  color: string;
  isCollapsed: boolean;
  onToggle: () => void;
  isDroppable: boolean;
}

/**
 * A category group of the dashboard's category sort mode. A real
 * category doubles as the drop target for moving a card into it; the
 * "Uncategorized" group has `isDroppable` off since dropping there has
 * no category to assign.
 */
export function CategoryGroupSection<T>({
  label,
  items,
  renderItem,
  color,
  isCollapsed,
  onToggle,
  isDroppable,
}: CategoryGroupSectionProps<T>) {
  const { setNodeRef, isOver } = useDroppable({
    id: label,
    disabled: !isDroppable,
  });

  return (
    <div ref={setNodeRef}>
      <GroupSection
        label={label}
        items={items}
        renderItem={renderItem}
        color={color}
        isCollapsed={isCollapsed}
        onToggle={onToggle}
        isDropTarget={isOver}
        emptyHint={
          isDroppable ? `Drop a game here to add it to ${label}` : undefined
        }
      />
    </div>
  );
}
