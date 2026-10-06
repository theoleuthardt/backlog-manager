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
}) {
  return BacklogEntry(
    id: id,
    title: title ?? 'Game $id',
    status: status,
    mainTime: mainTime,
    playtime: playtime,
    reviewStars: reviewStars,
    completedAt: completedAt,
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

  group('recentlyCompleted', () {
    test('lists completed games, the latest completion first', () {
      final result = recentlyCompleted([
        game(1, status: 'Completed', completedAt: DateTime(2026, 3, 1)),
        game(2, status: 'Completed', completedAt: DateTime(2026, 9, 1)),
        game(3, status: 'Completed', completedAt: DateTime(2026, 6, 1)),
        game(4, completedAt: DateTime(2026, 10, 1)),
      ]);

      expect(result.map((e) => e.id), [2, 3, 1]);
    });

    test('puts games without a completion date last', () {
      final result = recentlyCompleted([
        game(1, status: 'Completed'),
        game(2, status: 'Completed', completedAt: DateTime(2020)),
      ]);

      expect(result.map((e) => e.id), [2, 1]);
    });
  });
}
