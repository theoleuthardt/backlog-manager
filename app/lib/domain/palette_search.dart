import 'package:backlog_manager/domain/format.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/text_order.dart';

/// How well [query] matches [text], or null when it does not. A prefix scores
/// highest, then the start of a later word, then any substring, then the query
/// letters in order with gaps; a shorter text scores higher within a class.
/// Case and surrounding spaces do not matter; an empty query matches all.
int? fuzzyScore(String query, String text) {
  final needle = query.trim().toLowerCase();
  final haystack = text.toLowerCase();
  if (needle.isEmpty) return 0;

  final index = haystack.indexOf(needle);
  if (index == 0) return 4000 - haystack.length;
  if (index > 0) {
    final wordStart = !RegExp(r'[a-z0-9]').hasMatch(haystack[index - 1]);
    return (wordStart ? 3000 : 2000) - index - haystack.length;
  }

  var from = 0;
  var gaps = 0;
  for (final letter in needle.split('')) {
    final found = haystack.indexOf(letter, from);
    if (found < 0) return null;
    gaps += found - from;
    from = found + 1;
  }
  return 1000 - gaps - haystack.length;
}

/// The games that match [query], best first and then by title, at most
/// [limit]; nothing for an empty query.
List<BacklogEntry> rankGames(
  List<BacklogEntry> entries,
  String query, {
  int limit = 6,
}) {
  if (query.trim().isEmpty) return const [];
  final scored = <(BacklogEntry, int)>[];
  for (final entry in entries) {
    final score = fuzzyScore(query, entry.title);
    if (score != null) scored.add((entry, score));
  }
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    return byScore != 0 ? byScore : compareText(a.$1.title, b.$1.title);
  });
  return [for (final item in scored.take(limit)) item.$1];
}

/// The line under a game in the palette: the status, and "18 of 22 h" when
/// the hours played and the hours to beat are both known.
String gameMeta(BacklogEntry entry) {
  final played = entry.playtime;
  final toBeat = entry.mainTime;
  if (played == null || toBeat == null) return entry.status;
  return '${entry.status} · ${formatHours(played)} of ${formatHours(toBeat)} h';
}
