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

  /// Sum of the main-story hours of all games that have a time.
  final double timeToBeat;
  final int playingNow;
  final int completedThisYear;
}

HomeStats homeStats(List<BacklogEntry> entries, {required DateTime now}) {
  var time = 0.0;
  var playing = 0;
  var completed = 0;
  for (final entry in entries) {
    time += entry.mainTime ?? 0;
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

/// Games not started yet, the shortest main story first; games without a time
/// come last, ordered by title.
List<BacklogEntry> upNext(List<BacklogEntry> entries) {
  final games = entries.where((e) => e.status == _notStarted).toList();
  return stableSorted(games, (a, b) {
    final timeA = a.mainTime;
    final timeB = b.mainTime;
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

/// Completed games, the latest completion first; games without a date last.
List<BacklogEntry> recentlyCompleted(List<BacklogEntry> entries) {
  final games = entries.where((e) => e.status == _completed).toList();
  return stableSorted(games, (a, b) {
    final dateA = a.completedAt;
    final dateB = b.completedAt;
    if (dateA != null && dateB != null) return dateB.compareTo(dateA);
    if (dateA != null) return -1;
    if (dateB != null) return 1;
    return compareText(a.title, b.title);
  });
}
