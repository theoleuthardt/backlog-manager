import 'package:backlog_manager/domain/game_search.dart';
import 'package:flutter_test/flutter_test.dart';

GameSearchResult result({
  int id = 1,
  String title = 'Hades',
  String? imageUrl = 'https://img.example/hades.jpg',
  List<String> genres = const ['Roguelike', 'Action'],
  List<String> platforms = const ['PC', 'Switch'],
  double main = 22,
  double extra = 48,
  double completionist = 95,
  String? description = 'Defy the god of the dead.',
  String? publisher = 'Supergiant Games',
  String? trailerUrl = 'https://www.youtube.com/watch?v=abcdefghijk',
}) => GameSearchResult(
  id: id,
  title: title,
  imageUrl: imageUrl,
  genres: genres,
  platforms: platforms,
  mainStory: main,
  mainStoryWithExtras: extra,
  completionist: completionist,
  description: description,
  publisher: publisher,
  trailerUrl: trailerUrl,
);

void main() {
  group('creationToolLocation', () {
    test('carries everything the creation tool needs', () {
      final uri = Uri.parse(creationToolLocation(result()));

      expect(uri.path, '/creation-tool');
      expect(uri.queryParameters, {
        'title': 'Hades',
        'imageUrl': 'https://img.example/hades.jpg',
        'steamAppId': '',
        'genres': 'Roguelike, Action',
        'platforms': 'PC, Switch',
        'mainStory': '22',
        'mainStoryWithExtras': '48',
        'completionist': '95',
        'description': 'Defy the god of the dead.',
        'publisher': 'Supergiant Games',
        'trailerUrl': 'https://www.youtube.com/watch?v=abcdefghijk',
      });
    });

    test('cuts the description to 500 characters', () {
      final uri = Uri.parse(
        creationToolLocation(result(description: 'x' * 800)),
      );

      expect(uri.queryParameters['description'], 'x' * 500);
    });

    test('leaves out nothing for a result without the optional parts', () {
      final uri = Uri.parse(
        creationToolLocation(
          result(
            imageUrl: null,
            description: null,
            publisher: null,
            trailerUrl: null,
            genres: const [],
            platforms: const [],
          ),
        ),
      );

      expect(uri.queryParameters['imageUrl'], '');
      expect(uri.queryParameters['description'], '');
      expect(uri.queryParameters['publisher'], '');
      expect(uri.queryParameters['trailerUrl'], '');
      expect(uri.queryParameters['genres'], '');
    });

    test('keeps fractions of an hour', () {
      final uri = Uri.parse(creationToolLocation(result(main: 7.5)));

      expect(uri.queryParameters['mainStory'], '7.5');
    });

    test('names the shared space as the target', () {
      final uri = Uri.parse(creationToolLocation(result(), inSpace: true));

      expect(uri.queryParameters['target'], 'space');
      expect(
        Uri.parse(creationToolLocation(result())).queryParameters,
        isNot(contains('target')),
      );
    });

    test('escapes what needs escaping', () {
      final uri = Uri.parse(
        creationToolLocation(result(title: 'Overcooked! & Friends: 100%')),
      );

      expect(uri.queryParameters['title'], 'Overcooked! & Friends: 100%');
    });
  });

  group('customGameLocation', () {
    test('opens the creation tool in custom mode with the typed title', () {
      final uri = Uri.parse(customGameLocation('My game'));

      expect(uri.path, '/creation-tool');
      expect(uri.queryParameters, {'title': 'My game', 'custom': '1'});
    });

    test('names the shared space as the target', () {
      final uri = Uri.parse(customGameLocation('My game', inSpace: true));

      expect(uri.queryParameters['target'], 'space');
    });
  });

  group('timesLabel', () {
    test('writes the three times with slashes', () {
      expect(result().timesLabel, '22 / 48 / 95 h');
    });

    test('shows a dash for a time that is not known', () {
      expect(
        result(main: 0, extra: 0, completionist: 0).timesLabel,
        '– / – / – h',
      );
      expect(result(extra: 0).timesLabel, '22 / – / 95 h');
    });

    test('keeps one decimal for half hours', () {
      expect(result(main: 7.5).timesLabel, '7.5 / 48 / 95 h');
    });
  });

  group('hoursLine', () {
    test('names the three times', () {
      expect(
        result().hoursLine,
        'Main 22 h · +Extra 48 h · Completionist 95 h',
      );
    });

    test('shows two dashes for a time that is not known', () {
      expect(
        result(extra: 0).hoursLine,
        'Main 22 h · +Extra -- h · Completionist 95 h',
      );
    });
  });

  group('deeperIds', () {
    test('are the results the normal search did not return', () {
      final normal = [result(id: 1), result(id: 2)];
      final deep = [result(id: 2), result(id: 3), result(id: 4)];

      expect(deeperIds(normal: normal, deep: deep), {3, 4});
    });

    test('are empty when both searches agree', () {
      final same = [result(id: 1)];

      expect(deeperIds(normal: same, deep: same), isEmpty);
    });
  });

  group('wrongGameChanges', () {
    test('replaces the game with the chosen result', () {
      final changes = wrongGameChanges(result());

      expect(changes.title, 'Hades');
      expect(changes.genre, ['Roguelike', 'Action']);
      expect(changes.imageLink, 'https://img.example/hades.jpg');
      expect(changes.description, 'Defy the god of the dead.');
      expect(
        changes.trailerLink,
        'https://www.youtube.com/watch?v=abcdefghijk',
      );
      expect(changes.mainTime, 22);
      expect(changes.mainPlusExtraTime, 48);
      expect(changes.completionTime, 95);
      expect(changes.clearSteamAppId, isTrue);
    });

    test('keeps the genres of the entry when the result has none', () {
      expect(wrongGameChanges(result(genres: const [])).genre, isNull);
    });
  });
}
