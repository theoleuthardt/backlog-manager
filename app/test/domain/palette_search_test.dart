import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/palette_search.dart';
import 'package:flutter_test/flutter_test.dart';

BacklogEntry game(
  int id,
  String title, {
  String status = 'Not Started',
  double? playtime,
  double? mainTime,
}) => BacklogEntry(
  id: id,
  title: title,
  status: status,
  playtime: playtime,
  mainTime: mainTime,
);

void main() {
  group('fuzzyScore', () {
    test('does not match text that lacks the letters in order', () {
      expect(fuzzyScore('xyz', 'Hades'), isNull);
      expect(fuzzyScore('sad', 'Hades'), isNull);
    });

    test('ignores case and surrounding spaces', () {
      expect(fuzzyScore('  HADES ', 'hades'), isNotNull);
    });

    test('ranks a prefix above a word start above a substring', () {
      final prefix = fuzzyScore('ha', 'Hades')!;
      final word = fuzzyScore('ha', 'The Hades')!;
      final inside = fuzzyScore('ha', 'Shade')!;
      expect(prefix, greaterThan(word));
      expect(word, greaterThan(inside));
    });

    test('ranks a substring above scattered letters', () {
      expect(
        fuzzyScore('hds', 'Hades')!,
        lessThan(fuzzyScore('ade', 'Hades')!),
      );
    });

    test('ranks a shorter title higher for the same prefix', () {
      expect(
        fuzzyScore('hades', 'Hades')!,
        greaterThan(fuzzyScore('hades', 'Hades II')!),
      );
    });

    test('matches everything for an empty query', () {
      expect(fuzzyScore('', 'Hades'), isNotNull);
    });
  });

  group('rankGames', () {
    final games = [
      game(1, 'Shade Runner'),
      game(2, 'Hades II'),
      game(3, 'Hades'),
      game(4, 'Celeste'),
      game(5, 'Hollow Knight'),
    ];

    test('is empty without a query', () {
      expect(rankGames(games, ''), isEmpty);
      expect(rankGames(games, '   '), isEmpty);
    });

    test('orders by the score and then by title', () {
      expect(rankGames(games, 'ha').map((g) => g.title), [
        'Hades',
        'Hades II',
        'Shade Runner',
      ]);
    });

    test('finds scattered letters', () {
      expect(rankGames(games, 'hlwk').map((g) => g.title), ['Hollow Knight']);
    });

    test('caps the number of results', () {
      final many = [for (var i = 0; i < 20; i++) game(i, 'Game $i')];
      expect(rankGames(many, 'game', limit: 6), hasLength(6));
    });
  });

  group('gameMeta', () {
    test('shows the status and the hours played of the main story', () {
      expect(
        gameMeta(
          game(1, 'Hades', status: 'In Progress', playtime: 18, mainTime: 22),
        ),
        'In Progress · 18 of 22 h',
      );
    });

    test('is only the status without both times', () {
      expect(gameMeta(game(1, 'Hades', status: 'Completed')), 'Completed');
      expect(
        gameMeta(game(1, 'Hades', status: 'Completed', playtime: 5)),
        'Completed',
      );
    });
  });
}
