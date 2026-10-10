import { wishlistImportDate } from "~/lib/steamWishlist";

export interface WishlistChange {
  steamAppId: number;
  title: string;
  imageLink?: string;
}

export interface WishlistSyncReport {
  since?: string;
  updatedAt?: string;
  added: WishlistChange[];
  removed: WishlistChange[];
}

export interface WishlistDiffRow {
  sign: "+" | "-";
  steamAppId: number;
  title: string;
}

export function hasWishlistChanges(
  report: WishlistSyncReport | null | undefined,
): boolean {
  return Boolean(report && (report.added.length || report.removed.length));
}

export function wishlistDiffRows(
  report: WishlistSyncReport,
): WishlistDiffRow[] {
  return [
    ...report.removed.map((change) => ({
      sign: "-" as const,
      steamAppId: change.steamAppId,
      title: change.title,
    })),
    ...report.added.map((change) => ({
      sign: "+" as const,
      steamAppId: change.steamAppId,
      title: change.title,
    })),
  ];
}

function count(amount: number, verb: string): string | null {
  if (amount === 0) return null;
  return `${amount} game${amount === 1 ? "" : "s"} ${verb}`;
}

export function wishlistSyncSummary(report: WishlistSyncReport): string {
  const parts = [
    count(report.added.length, "added"),
    count(report.removed.length, "removed"),
  ].filter((part) => part !== null);
  const since = wishlistImportDate(report.since);
  return since ? `${parts.join(", ")} since ${since}` : parts.join(", ");
}
