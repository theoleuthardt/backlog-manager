import 'dart:math';

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
}
