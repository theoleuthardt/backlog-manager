import 'package:backlog_manager/domain/home_logic.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

BacklogEntry game(
  int id, {
  String status = 'Not Started',
  double? mainTime,
  double? playtime,
  int? reviewStars,
  DateTime? completedAt,
  String? title,
  int interest = 0,
  List<String> genre = const [],
}) {
  return BacklogEntry(
    id: id,
    title: title ?? 'Game $id',
    status: status,
    mainTime: mainTime,
    playtime: playtime,
    reviewStars: reviewStars,
    completedAt: completedAt,
    interest: interest,
    genre: genre,
  );
}

void main() {
  final now = DateTime(2026, 10, 7);

  group('homeStats', () {
    test('counts the games in the backlog', () {
      final stats = homeStats([
        game(1),
        game(2),
        game(3, status: 'Completed'),
      ], now: now);

      expect(stats.inBacklog, 3);
    });

    test('sums the main-story hours and ignores games without a time', () {
      final stats = homeStats([
        game(1, mainTime: 10.5),
        game(2, mainTime: 20),
        game(3),
      ], now: now);

      expect(stats.timeToBeat, 30.5);
    });

    test('counts the games that are being played', () {
      final stats = homeStats([
        game(1, status: 'In Progress'),
        game(2, status: 'In Progress'),
        game(3),
      ], now: now);

      expect(stats.playingNow, 2);
    });

    test('counts only the completions of this year', () {
      final stats = homeStats([
        game(1, status: 'Completed', completedAt: DateTime(2026, 1, 2)),
        game(2, status: 'Completed', completedAt: DateTime(2026, 9, 30)),
        game(3, status: 'Completed', completedAt: DateTime(2025, 12, 31)),
        game(4, status: 'Completed'),
        game(5, completedAt: DateTime(2026, 5, 5)),
      ], now: now);

      expect(stats.completedThisYear, 2);
    });

    test('is all zero for an empty backlog', () {
      final stats = homeStats(const [], now: now);

      expect(
        (
          stats.inBacklog,
          stats.timeToBeat,
          stats.playingNow,
          stats.completedThisYear,
        ),
        (0, 0.0, 0, 0),
      );
    });
  });

  group('continuePlaying', () {
    test('is the game in progress with the most playtime', () {
      final result = continuePlaying([
        game(1, status: 'In Progress', playtime: 5),
        game(2, status: 'In Progress', playtime: 41),
        game(3, status: 'Completed', playtime: 200),
        game(4, status: 'In Progress', playtime: 12),
      ]);

      expect(result?.id, 2);
    });

    test('treats a missing playtime as none and breaks a tie by title', () {
      final result = continuePlaying([
        game(1, status: 'In Progress', title: 'Zelda'),
        game(2, status: 'In Progress', title: 'Alpha'),
      ]);

      expect(result?.title, 'Alpha');
    });

    test('is null when nothing is in progress', () {
      expect(continuePlaying([game(1), game(2, status: 'Completed')]), isNull);
    });
  });

  group('upNext', () {
    test('lists the games not started, shortest main story first', () {
      final result = upNext([
        game(1, mainTime: 30),
        game(2, mainTime: 5),
        game(3, mainTime: 12),
        game(4, status: 'Completed', mainTime: 1),
      ]);

      expect(result.map((e) => e.id), [2, 3, 1]);
    });

    test('puts games without a time last, by title', () {
      final result = upNext([
        game(1, title: 'Zebra'),
        game(2, mainTime: 8),
        game(3, title: 'Apple'),
      ]);

      expect(result.map((e) => e.id), [2, 3, 1]);
    });

    test('is empty without games to start', () {
      expect(upNext([game(1, status: 'Completed')]), isEmpty);
    });
  });

  group('upNext by interest', () {
    test('puts the highest interest first, whatever the time', () {
      final result = upNext([
        game(1, interest: 5, mainTime: 2),
        game(2, interest: 10, mainTime: 90),
        game(3, interest: 9, mainTime: 40),
      ]);

      expect(result.map((e) => e.id), [2, 3, 1]);
    });

    test('takes the shorter game of the same interest first', () {
      final result = upNext([
        game(1, interest: 8, mainTime: 30),
        game(2, interest: 8, mainTime: 5),
      ]);

      expect(result.map((e) => e.id), [2, 1]);
    });
  });

  group('statusCounts', () {
    test('counts the games per status, the largest first', () {
      final result = statusCounts([
        game(1),
        game(2, status: 'Completed'),
        game(3, status: 'Completed'),
        game(4, status: 'In Progress'),
      ]);

      expect(result, [
        (label: 'Completed', count: 2),
        (label: 'In Progress', count: 1),
        (label: 'Not Started', count: 1),
      ]);
    });
  });

  group('topGenres', () {
    test('counts every genre of a game, the largest first', () {
      final result = topGenres([
        game(1, genre: ['RPG', 'Action']),
        game(2, genre: ['RPG']),
        game(3, genre: ['Puzzle']),
      ]);

      expect(result, [
        (label: 'RPG', count: 2),
        (label: 'Action', count: 1),
        (label: 'Puzzle', count: 1),
      ]);
    });

    test('keeps the largest ones up to the limit', () {
      final result = topGenres([
        game(1, genre: ['A', 'B', 'C']),
        game(2, genre: ['C']),
      ], limit: 2);

      expect(result.map((e) => e.label), ['C', 'A']);
    });
  });

  group('monthlyCompletions', () {
    test('lists the last months up to now, the oldest first', () {
      final result = monthlyCompletions(
        [
          game(1, status: 'Completed', completedAt: DateTime(2026, 10, 2)),
          game(2, status: 'Completed', completedAt: DateTime(2026, 10, 3)),
          game(3, status: 'Completed', completedAt: DateTime(2026, 8, 1)),
          game(4, status: 'Completed', completedAt: DateTime(2025, 8, 1)),
          game(5, status: 'Completed'),
          game(6, completedAt: DateTime(2026, 10, 1)),
        ],
        now: now,
        months: 4,
      );

      expect(result, [
        (month: DateTime(2026, 7), count: 0),
        (month: DateTime(2026, 8), count: 1),
        (month: DateTime(2026, 9), count: 0),
        (month: DateTime(2026, 10), count: 2),
      ]);
    });

    test('crosses the turn of the year', () {
      final result = monthlyCompletions(
        const [],
        now: DateTime(2026, 2, 28),
        months: 3,
      );

      expect(result.map((e) => e.month), [
        DateTime(2025, 12),
        DateTime(2026),
        DateTime(2026, 2),
      ]);
    });
  });
}
