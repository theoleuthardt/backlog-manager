import { splitList } from "~/lib/splitList";
import type { BacklogEntryProps } from "~/app/types/backlog";

export interface EntryForm {
  imageLink: string;
  playtime: number | undefined;
  genre: string;
  platform: string;
  status: string;
  owned: boolean;
  interest: number;
  reviewStars: number;
  review: string;
  note: string;
}

export interface EntryFormChanges {
  imageLink?: string;
  genre?: string[];
  platform?: string[];
  status?: string;
  owned?: boolean;
  interest?: number;
  playtime?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
}

/**
 * The fields of the entry dialog's form that differ from the stored
 * entry, in the shape the update mutation takes. An empty object means
 * there is nothing to save.
 */
export function diffEntryForm(
  form: EntryForm,
  entry: BacklogEntryProps,
): EntryFormChanges {
  const changes: EntryFormChanges = {};
  if (form.imageLink !== entry.imageLink) changes.imageLink = form.imageLink;
  if (form.playtime !== undefined && form.playtime !== entry.playtime)
    changes.playtime = form.playtime;
  if (form.genre !== (entry.genre?.join(", ") ?? ""))
    changes.genre = splitList(form.genre);
  if (form.platform !== (entry.platform?.join(", ") ?? ""))
    changes.platform = splitList(form.platform);
  if (form.status !== (entry.status ?? "")) changes.status = form.status;
  if (form.owned !== (entry.owned ?? false)) changes.owned = form.owned;
  if (form.interest !== (entry.interest ?? 0)) changes.interest = form.interest;
  if (form.reviewStars !== (entry.reviewStars ?? 0))
    changes.reviewStars = form.reviewStars;
  if (form.review !== (entry.review ?? "")) changes.review = form.review;
  if (form.note !== (entry.note ?? "")) changes.note = form.note;
  return changes;
}
