const STATUS_COLORS: Record<string, string> = {
  "Not Started": "#94a3b8",
  "In Progress": "#38bdf8",
  Completed: "#4ade80",
  "On Hold": "#fbbf24",
  Dropped: "#f87171",
};

const CUSTOM_STATUS_COLOR = "#c084fc";

export function statusColor(status: string): string {
  return STATUS_COLORS[status] ?? CUSTOM_STATUS_COLOR;
}
