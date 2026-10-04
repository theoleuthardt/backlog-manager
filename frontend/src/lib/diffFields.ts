export interface FieldDiffEntry {
  field: string;
  existing: string;
  proposed: string;
}

interface DiffableFields {
  genre: string[];
  platform: string[];
  status: string;
  owned: boolean;
  playtime?: number;
  reviewStars?: number;
  note?: string;
}

function formatNumber(value: number | undefined): string {
  return value === undefined ? "" : String(value);
}

export function computeFieldDiffs(
  existing: DiffableFields,
  proposed: DiffableFields,
): FieldDiffEntry[] {
  const pairs: Array<[string, string, string]> = [
    ["genre", existing.genre.join(", "), proposed.genre.join(", ")],
    ["platform", existing.platform.join(", "), proposed.platform.join(", ")],
    ["status", existing.status, proposed.status],
    ["owned", existing.owned ? "Yes" : "No", proposed.owned ? "Yes" : "No"],
    [
      "playtime",
      formatNumber(existing.playtime),
      formatNumber(proposed.playtime),
    ],
    [
      "review_stars",
      formatNumber(existing.reviewStars),
      formatNumber(proposed.reviewStars),
    ],
    ["note", existing.note ?? "", proposed.note ?? ""],
  ];

  return pairs
    .filter(
      ([, existingValue, proposedValue]) => existingValue !== proposedValue,
    )
    .map(([field, existingValue, proposedValue]) => ({
      field,
      existing: existingValue,
      proposed: proposedValue,
    }));
}
