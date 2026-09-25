"use client";
import { useDroppable } from "@dnd-kit/core";
import { ChevronDown } from "lucide-react";
import { statusColor } from "~/lib/statusStyle";

interface StatusGroupSectionProps {
  status: string;
  count: number;
  isCollapsed: boolean;
  onToggle: () => void;
  children: React.ReactNode;
}

/**
 * One status group of the dashboard: a headline with the entry count
 * and a collapse toggle, over a grid that doubles as the drop target
 * for dragging cards between statuses. An empty group renders a slim
 * dashed placeholder so it can still be dropped onto.
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
    <section
      ref={setNodeRef}
      aria-label={`${status} games`}
      className={`rounded-2xl border-2 p-3 transition-colors duration-150 ${
        isOver
          ? "surface-glow border-primary bg-primary/10"
          : "border-transparent"
      }`}
    >
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={!isCollapsed}
        className="group-heading mb-3 flex w-full cursor-pointer items-center gap-3 text-left"
      >
        <span
          aria-hidden="true"
          className="h-3 w-3 shrink-0 rounded-full"
          style={{
            backgroundColor: statusColor(status),
            boxShadow: `0 0 10px ${statusColor(status)}`,
          }}
        />
        <h2 className="text-xl font-bold tracking-wide">{status}</h2>
        <span className="rounded-full bg-white/10 px-2.5 py-0.5 text-sm font-medium">
          {count}
        </span>
        <span
          aria-hidden="true"
          className="h-px flex-1"
          style={{
            background: `linear-gradient(to right, ${statusColor(status)}66, transparent)`,
          }}
        />
        <ChevronDown
          className={`h-5 w-5 shrink-0 transition-transform duration-200 ${
            isCollapsed ? "-rotate-90" : ""
          }`}
        />
      </button>
      {!isCollapsed &&
        (count > 0 ? (
          <div className="grid grid-cols-[repeat(auto-fill,minmax(9.375rem,1fr))] justify-items-center gap-2">
            {children}
          </div>
        ) : (
          <p className="rounded-xl border border-dashed border-white/30 px-4 py-5 text-center text-sm text-white/60">
            Drop a game here to mark it as {status}
          </p>
        ))}
    </section>
  );
};
