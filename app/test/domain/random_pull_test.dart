import 'dart:math';

import 'package:backlog_manager/domain/library_groups.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/random_pull.dart';
import 'package:flutter_test/flutter_test.dart';

BacklogEntry game(int id, {String status = 'Not Started', bool owned = true}) =>
    BacklogEntry(
      id: id,
      title: 'Game $id',
      status: status,
      owned: owned,
      interest: 5,
    );

void main() {
  group('pullCandidates', () {
    final entries = [
      game(1),
      game(2, status: 'In Progress'),
      game(3, status: 'On Hold'),
      game(4, status: 'Completed'),
      game(5, status: 'Dropped'),
      game(6, status: 'Not Owned', owned: false),
      game(7, status: 'Replaying'),
      game(8, owned: false),
    ];

    List<int> ids({required bool includeFinished}) => [
      for (final e in pullCandidates(entries, includeFinished: includeFinished))
        e.id,
    ];

    test('keeps the games that are still to play', () {
      expect(ids(includeFinished: false), [1, 2, 3, 7]);
    });

    test('leaves out finished and dropped games', () {
      final pool = ids(includeFinished: false);

      expect(pool, isNot(contains(4)));
      expect(pool, isNot(contains(5)));
    });

    test('takes the finished and dropped games when they are included', () {
      expect(ids(includeFinished: true), [1, 2, 3, 4, 5, 7]);
    });

    test('never takes a game the user does not own', () {
      for (final includeFinished in [false, true]) {
        final pool = ids(includeFinished: includeFinished);

        expect(pool, isNot(contains(6)));
        expect(pool, isNot(contains(8)));
      }
    });
  });

  group('pickRandom', () {
    final pool = [game(1), game(2), game(3)];

    test('is null for an empty pool', () {
      expect(pickRandom(const [], Random(1)), isNull);
    });

    test('is the only game of a pool of one, also when it was just pulled', () {
      final only = [game(9)];

      expect(pickRandom(only, Random(1))!.id, 9);
      expect(pickRandom(only, Random(1), exceptId: 9)!.id, 9);
    });

    test('never repeats the game that was just pulled', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(pickRandom(pool, Random(seed), exceptId: 2)!.id, isNot(2));
      }
    });

    test('can pick every game of the pool', () {
      final random = Random(7);
      final seen = {for (var i = 0; i < 200; i++) pickRandom(pool, random)!.id};

      expect(seen, {1, 2, 3});
    });

    test(
      'is fair: each of three games is picked about a third of the time',
      () {
        final random = Random(42);
        final counts = <int, int>{};
        for (var i = 0; i < 3000; i++) {
          final id = pickRandom(pool, random)!.id;
          counts[id] = (counts[id] ?? 0) + 1;
        }

        for (final count in counts.values) {
          expect(count, inInclusiveRange(850, 1150));
        }
      },
    );
  });

  group('pullPool', () {
    final groups = [
      LibraryGroup(
        key: 'status:In Progress',
        label: 'In Progress',
        entries: [
          game(1, status: 'In Progress'),
          game(2, status: 'In Progress'),
        ],
      ),
      LibraryGroup(
        key: 'status:Completed',
        label: 'Completed',
        entries: [game(3, status: 'Completed')],
      ),
      LibraryGroup(
        key: 'status:Backlog',
        label: 'Backlog',
        entries: [game(4), game(5, owned: false)],
      ),
    ];

    List<int> ids({
      Set<String> excluded = const {},
      bool includeFinished = false,
    }) => [
      for (final e in pullPool(
        groups,
        excluded: excluded,
        includeFinished: includeFinished,
      ))
        e.id,
    ];

    test('takes the games of every group without an exclusion', () {
      expect(ids(), [1, 2, 4]);
    });

    test('leaves out the games of an excluded group', () {
      expect(ids(excluded: {'status:In Progress'}), [4]);
    });

    test('still applies the rules of pullCandidates', () {
      expect(ids(includeFinished: true), [1, 2, 3, 4]);
      expect(ids(excluded: {'status:Backlog'}, includeFinished: true), [
        1,
        2,
        3,
      ]);
    });

    test('is empty when every group is left out', () {
      expect(
        ids(
          excluded: {
            'status:In Progress',
            'status:Completed',
            'status:Backlog',
          },
        ),
        isEmpty,
      );
    });

    test('counts the games a group offers', () {
      expect(groupPullCount(groups[0], includeFinished: false), 2);
      expect(groupPullCount(groups[1], includeFinished: false), 0);
      expect(groupPullCount(groups[1], includeFinished: true), 1);
      expect(groupPullCount(groups[2], includeFinished: false), 1);
    });
  });

  group('reelStrip', () {
    final pool = [for (var i = 1; i <= 5; i++) game(i)];
    final big = [for (var i = 1; i <= 80; i++) game(i)];

    ReelStrip strip({
      List<BacklogEntry>? from,
      int pick = 2,
      int minLength = 12,
      int trailing = 3,
      int seed = 1,
    }) {
      final games = from ?? pool;
      return reelStrip(
        games,
        games[pick],
        minLength: minLength,
        trailing: trailing,
        random: Random(seed),
      );
    }

    List<int> ids(ReelStrip result) => [for (final e in result.games) e.id];

    test('stops on the game that was pulled', () {
      final result = strip(from: big, pick: 41);

      expect(result.games[result.stopIndex].id, 42);
    });

    test('shows every game of a large pool once before it stops', () {
      final result = strip(from: big, pick: 10, minLength: 12);
      final before = ids(result).sublist(0, result.stopIndex + 1);

      expect(before, hasLength(80));
      expect(before.toSet(), {for (final e in big) e.id});
    });

    test('is not longer than the pool when the pool is long enough', () {
      final result = strip(from: big, minLength: 30, trailing: 3);

      expect(result.stopIndex, 79);
      expect(result.games, hasLength(83));
    });

    test('repeats a small pool in whole rounds, every game equally often', () {
      final result = strip(minLength: 12);
      final before = ids(result).sublist(0, result.stopIndex + 1);

      expect(before, hasLength(15));
      for (final e in pool) {
        expect(
          before.where((id) => id == e.id),
          hasLength(3),
          reason: 'game ${e.id}',
        );
      }
      expect(result.games[result.stopIndex].id, 3);
    });

    test('does not repeat a pool that is long enough on its own', () {
      final result = strip(from: pool, minLength: 5);

      expect(result.stopIndex, 4);
    });

    test('goes on after the game it stops on, like an endless spin', () {
      final result = strip(trailing: 3);

      expect(result.games.length - 1 - result.stopIndex, 3);
    });

    test('only shows games of the pool', () {
      final result = strip(from: big, seed: 2);

      expect(result.games.every((e) => big.any((p) => p.id == e.id)), isTrue);
    });

    test('never shows the same game twice in a row, before or after', () {
      for (var seed = 0; seed < 30; seed++) {
        for (final from in [pool, big, pool.sublist(0, 2)]) {
          final games = strip(
            from: from,
            pick: 1,
            minLength: 30,
            seed: seed,
          ).games;
          for (var i = 1; i < games.length; i++) {
            expect(
              games[i].id,
              isNot(games[i - 1].id),
              reason: 'seed $seed, ${from.length} games',
            );
          }
        }
      }
    });

    test('is shuffled, and the same for the same seed', () {
      expect(ids(strip(from: big, seed: 7)), ids(strip(from: big, seed: 7)));
      expect(
        ids(strip(from: big, seed: 7)),
        isNot(ids(strip(from: big, seed: 8))),
      );
    });

    test('repeats the only game of a pool of one', () {
      final result = strip(from: [pool[0]], pick: 0, minLength: 4, trailing: 2);

      expect(ids(result), [1, 1, 1, 1, 1, 1]);
      expect(result.stopIndex, 3);
    });
  });

  group('reelSparks', () {
    test('are strongest while the reel is fast', () {
      expect(reelSparks(0, rows: 27, seconds: 2.6), 1);
      expect(reelSparks(0.2, rows: 27, seconds: 2.6), 1);
    });

    test('die down as the reel slows and stop with it', () {
      expect(
        reelSparks(0.6, rows: 27, seconds: 2.6),
        inInclusiveRange(0.1, 0.9),
      );
      expect(reelSparks(0.95, rows: 27, seconds: 2.6), 0);
      expect(reelSparks(1, rows: 27, seconds: 2.6), 0);
    });

    test('never grow while the reel slows down', () {
      var previous = reelSparks(0, rows: 27, seconds: 2.6);
      for (var t = 0.05; t <= 1; t += 0.05) {
        final now = reelSparks(t, rows: 27, seconds: 2.6);
        expect(now, lessThanOrEqualTo(previous));
        previous = now;
      }
    });
  });
}
