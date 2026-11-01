import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/text_order.dart';

const _inProgress = 'In Progress';
const _notStarted = 'Not Started';
const _completed = 'Completed';

/// The four tiles of the home screen.
class HomeStats {
  const HomeStats({
    required this.inBacklog,
    required this.timeToBeat,
    required this.playingNow,
    required this.completedThisYear,
  });

  /// Number of games.
  final int inBacklog;

  /// Sum of the hours to beat of all games that have a time (the main story,
  /// else main plus extra, else the completionist time).
  final double timeToBeat;
  final int playingNow;
  final int completedThisYear;
}

HomeStats homeStats(List<BacklogEntry> entries, {required DateTime now}) {
  var time = 0.0;
  var playing = 0;
  var completed = 0;
  for (final entry in entries) {
    time += entry.timeToBeat ?? 0;
    if (entry.status == _inProgress) playing++;
    if (entry.status == _completed && entry.completedAt?.year == now.year) {
      completed++;
    }
  }
  return HomeStats(
    inBacklog: entries.length,
    timeToBeat: time,
    playingNow: playing,
    completedThisYear: completed,
  );
}

/// The game in progress with the most playtime, for the hero card.
BacklogEntry? continuePlaying(List<BacklogEntry> entries) {
  BacklogEntry? best;
  for (final entry in entries.where((e) => e.status == _inProgress)) {
    if (best == null) {
      best = entry;
      continue;
    }
    final byPlaytime = (entry.playtime ?? 0).compareTo(best.playtime ?? 0);
    if (byPlaytime > 0 ||
        (byPlaytime == 0 && compareText(entry.title, best.title) < 0)) {
      best = entry;
    }
  }
  return best;
}

/// Games not started yet, the highest interest first, then the shortest main
/// story; games without a time come after the others of their interest,
/// ordered by title.
List<BacklogEntry> upNext(List<BacklogEntry> entries) {
  final games = entries.where((e) => e.status == _notStarted).toList();
  return stableSorted(games, (a, b) {
    final byInterest = b.interest.compareTo(a.interest);
    if (byInterest != 0) return byInterest;
    final timeA = a.timeToBeat;
    final timeB = b.timeToBeat;
    if (timeA != null && timeB != null) {
      final byTime = timeA.compareTo(timeB);
      if (byTime != 0) return byTime;
    } else if (timeA != null) {
      return -1;
    } else if (timeB != null) {
      return 1;
    }
    return compareText(a.title, b.title);
  });
}

/// A named number of games for a chart of the home screen.
typedef HomeCount = ({String label, int count});

/// How often each label comes up, the largest first, then by label.
List<HomeCount> _counted(Iterable<String> labels) {
  final counts = <String, int>{};
  for (final label in labels) {
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final result = [
    for (final MapEntry(:key, :value) in counts.entries)
      (label: key, count: value),
  ];
  return stableSorted(result, (a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : compareText(a.label, b.label);
  });
}

/// The number of games in each status.
List<HomeCount> statusCounts(List<BacklogEntry> entries) =>
    _counted(entries.map((entry) => entry.status));

/// The [limit] most common genres; a game counts for each of its genres.
List<HomeCount> topGenres(List<BacklogEntry> entries, {int limit = 6}) =>
    _counted(entries.expand((entry) => entry.genre)).take(limit).toList();

/// The completed games of each of the last [months] months up to [now], the
/// oldest first; games without a completion date do not count.
List<({DateTime month, int count})> monthlyCompletions(
  List<BacklogEntry> entries, {
  required DateTime now,
  int months = 12,
}) {
  final counts = <DateTime, int>{};
  for (final entry in entries) {
    final date = entry.completedAt;
    if (entry.status != _completed || date == null) continue;
    final month = DateTime(date.year, date.month);
    counts[month] = (counts[month] ?? 0) + 1;
  }
  return [
    for (var back = months - 1; back >= 0; back--)
      if (DateTime(now.year, now.month - back) case final month)
        (month: month, count: counts[month] ?? 0),
  ];
}
