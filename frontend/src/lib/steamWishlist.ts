/**
 * The date of the first Steam wishlist import as shown on the Steam page
 * ("10 Oct 2026"), or null when the wishlist was never imported (or the
 * date cannot be read). The wishlist import is for the first time only:
 * once this has a date the page no longer offers it.
 */
export function wishlistImportDate(
  importedAt: string | undefined,
): string | null {
  if (!importedAt) return null;
  const date = new Date(
    /[zZ]|[+-]\d\d:\d\d$/.test(importedAt) ? importedAt : `${importedAt}Z`,
  );
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  });
}

/**
 * The toast text when a wishlist import created fewer entries than the
 * preview listed because Steam's store could not name some games right
 * now; they are left out rather than imported under their app id, and the
 * import stays available for another try. Null when nothing was left out.
 */
export function skippedWishlistMessage(
  previewed: number,
  created: number,
): string | null {
  const skipped = previewed - created;
  if (skipped <= 0) return null;
  return `${skipped} game${skipped === 1 ? "" : "s"} could not be named by Steam right now and ${skipped === 1 ? "was" : "were"} left out - try the import again later`;
}
