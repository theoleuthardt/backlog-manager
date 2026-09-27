import { ChevronDown } from "lucide-react";

interface GroupSectionProps {
  label: string;
  count: number;
  color: string;
  isCollapsed: boolean;
  onToggle: () => void;
  isDropTarget?: boolean;
  emptyHint?: string;
  children: React.ReactNode;
}

/**
 * One group of the dashboard: a headline with the entry count and a
 * collapse toggle over a grid of cards. With `emptyHint` an empty group
 * renders a slim dashed placeholder (used for drag-and-drop targets)
 * instead of the grid.
 */
export const GroupSection = ({
  label,
  count,
  color,
  isCollapsed,
  onToggle,
  isDropTarget = false,
  emptyHint,
  children,
}: GroupSectionProps) => (
  <section
    aria-label={`${label} games`}
    className={`rounded-2xl border-2 p-3 transition-colors duration-150 ${
      isDropTarget
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
        style={{ backgroundColor: color, boxShadow: `0 0 10px ${color}` }}
      />
      <h2 className="text-xl font-bold tracking-wide">{label}</h2>
      <span className="rounded-full bg-white/10 px-2.5 py-0.5 text-sm font-medium">
        {count}
      </span>
      <span
        aria-hidden="true"
        className="h-px flex-1"
        style={{
          background: `linear-gradient(to right, ${color}66, transparent)`,
        }}
      />
      <ChevronDown
        className={`h-5 w-5 shrink-0 transition-transform duration-200 ${
          isCollapsed ? "-rotate-90" : ""
        }`}
      />
    </button>
    {!isCollapsed &&
      (count > 0 || !emptyHint ? (
        <div className="grid grid-cols-[repeat(auto-fill,minmax(9.375rem,1fr))] justify-items-center gap-2">
          {children}
        </div>
      ) : (
        <p className="rounded-xl border border-dashed border-white/30 px-4 py-5 text-center text-sm text-white/60">
          {emptyHint}
        </p>
      ))}
  </section>
);
