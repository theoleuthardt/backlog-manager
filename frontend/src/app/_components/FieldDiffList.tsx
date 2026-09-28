import type { FieldDiffEntry } from "~/lib/diffFields";

const FIELD_LABELS: Record<string, string> = {
  genre: "Genre",
  platform: "Platform",
  status: "Status",
  owned: "Owned",
  playtime: "Playtime",
  review_stars: "Review Stars",
  note: "Note",
  completed_at: "Completed At",
};

export function FieldDiffList({ diffs }: { diffs: FieldDiffEntry[] }) {
  if (diffs.length === 0) {
    return (
      <p className="text-xs text-gray-400">No differences from the existing entry.</p>
    );
  }

  return (
    <div className="overflow-hidden rounded border border-gray-700 font-mono text-xs">
      {diffs.map((diff) => (
        <div key={diff.field} className="border-b border-gray-700 last:border-b-0">
          <div className="bg-white/5 px-2 py-0.5 text-[10px] font-semibold tracking-wide text-gray-400">
            {FIELD_LABELS[diff.field] ?? diff.field}
          </div>
          <div className="bg-red-950/40 px-2 py-0.5 whitespace-pre-wrap text-red-400">
            <span className="select-none">- </span>
            {diff.existing || "(empty)"}
          </div>
          <div className="bg-green-950/40 px-2 py-0.5 whitespace-pre-wrap text-green-400">
            <span className="select-none">+ </span>
            {diff.proposed || "(empty)"}
          </div>
        </div>
      ))}
    </div>
  );
}
