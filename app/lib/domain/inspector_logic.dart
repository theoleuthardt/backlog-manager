import 'package:backlog_manager/domain/entry_changes.dart';
import 'package:backlog_manager/domain/format.dart';
import 'package:backlog_manager/domain/models.dart';

/// The values the inspector form starts with for [entry].
EntryForm entryFormFrom(BacklogEntry entry) {
  return EntryForm(
    imageLink: entry.imageLink,
    playtime: entry.playtime,
    genre: entry.genre.join(', '),
    platform: entry.platform.join(', '),
    status: entry.status,
    owned: entry.owned,
    interest: entry.interest,
    reviewStars: entry.reviewStars ?? 0,
    review: entry.review ?? '',
    note: entry.note ?? '',
  );
}

/// Stars and the review text can only be written for a completed game.
bool canReview(String status) => status == 'Completed';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Completed on March 2026", or null for a game with no completion date.
String? completedOnLabel(DateTime? completedAt) {
  if (completedAt == null) return null;
  final date = completedAt.toLocal();
  return 'Completed on ${_months[date.month - 1]} ${date.year}';
}

/// How much of a bar is filled: the hours played against the [hours] to beat,
/// at most the whole bar and empty when there are no hours to beat.
double beatFraction(double? hours, double? playtime) {
  if (hours == null || hours <= 0) return 0;
  return ((playtime ?? 0) / hours).clamp(0, 1).toDouble();
}

/// "22 h" for the hours to beat, "--" when there are none.
String beatHoursLabel(double? hours) {
  if (hours == null || hours <= 0) return '--';
  return '${formatHours(hours)} h';
}

/// The hours typed into the playtime field: a number of at least 0, or null
/// when the text is empty or not a number.
double? parsePlaytime(String text) {
  final value = double.tryParse(text.trim());
  if (value == null || !value.isFinite) return null;
  return value < 0 ? 0 : value;
}

/// The [form] after the stored entry changed from [from] to [to] while the
/// inspector was open (a drag to another status group, a sync): every field
/// the user has not touched takes the new stored value, so the autosave does
/// not write the old one back; an edited field keeps the edit.
EntryForm rebaseForm({
  required EntryForm form,
  required EntryForm from,
  required EntryForm to,
}) {
  T pick<T>(T current, T before, T after) =>
      current == before ? after : current;
  return EntryForm(
    imageLink: pick(form.imageLink, from.imageLink, to.imageLink),
    playtime: pick(form.playtime, from.playtime, to.playtime),
    genre: pick(form.genre, from.genre, to.genre),
    platform: pick(form.platform, from.platform, to.platform),
    status: pick(form.status, from.status, to.status),
    owned: pick(form.owned, from.owned, to.owned),
    interest: pick(form.interest, from.interest, to.interest),
    reviewStars: pick(form.reviewStars, from.reviewStars, to.reviewStars),
    review: pick(form.review, from.review, to.review),
    note: pick(form.note, from.note, to.note),
  );
}
