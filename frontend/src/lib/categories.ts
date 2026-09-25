export const CATEGORY_NAME_MAX_LENGTH = 40;

export const CATEGORY_COLORS = [
  "#38bdf8",
  "#4ade80",
  "#fbbf24",
  "#f87171",
  "#c084fc",
  "#fb923c",
  "#2dd4bf",
  "#f472b6",
] as const;

export function nextCategoryColor(existingCount: number): string {
  return CATEGORY_COLORS[existingCount % CATEGORY_COLORS.length] ?? "#38bdf8";
}

/**
 * Validation message for a new or renamed category, or "" when the
 * name is fine. Names double as the filter key, so duplicates are
 * rejected case-insensitively; `otherNames` must exclude the category
 * being renamed.
 */
export function categoryNameError(
  name: string,
  otherNames: readonly string[],
): string {
  const trimmed = name.trim();
  if (trimmed.length === 0) return "";
  if (trimmed.length > CATEGORY_NAME_MAX_LENGTH)
    return `Max ${CATEGORY_NAME_MAX_LENGTH} characters`;
  const lower = trimmed.toLowerCase();
  if (otherNames.some((other) => other.trim().toLowerCase() === lower))
    return "You already have a category with that name";
  return "";
}
