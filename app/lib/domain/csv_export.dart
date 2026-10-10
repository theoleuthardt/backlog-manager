import 'package:backlog_manager/domain/models.dart';

String _text(String? value) => '"${(value ?? '').replaceAll('"', '""')}"';

/// A number the way the web client writes it: whole numbers without a
/// decimal, empty for a missing one.
String _number(num? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();
}

/// The CSV of [entries]: one line per entry with the thirteen columns title,
/// genre, platform, status, owned, interest, review stars, review, note, main
/// time, main + extra time, completionist time and image link, text in quotes
/// with quotes doubled, no header row and no line break at the end. These are
/// the columns the import reads, and what the web client writes. With
/// [includeReviews] off the review and the note are written empty, so the
/// columns keep their place.
String buildCsv(List<BacklogEntry> entries, {bool includeReviews = true}) {
  return entries
      .map(
        (entry) => [
          _text(entry.title),
          _text(entry.genre.join(', ')),
          _text(entry.platform.join(', ')),
          _text(entry.status),
          entry.owned ? 'true' : 'false',
          _number(entry.interest),
          _number(entry.reviewStars),
          _text(includeReviews ? entry.review : ''),
          _text(includeReviews ? entry.note : ''),
          _number(entry.mainTime),
          _number(entry.mainPlusExtraTime),
          _number(entry.completionTime),
          _text(entry.imageLink),
        ].join(','),
      )
      .join('\n');
}

/// The entries with [status], or all of them without one.
List<BacklogEntry> entriesWithStatus(
  List<BacklogEntry> entries,
  String? status,
) {
  if (status == null) return entries;
  return entries.where((entry) => entry.status == status).toList();
}

/// `backlog-export-2026-10-09.csv`, named after the day in UTC.
String exportFileName(DateTime now) {
  final day = now.toUtc().toIso8601String().split('T').first;
  return 'backlog-export-$day.csv';
}
