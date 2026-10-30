import 'package:backlog_manager/domain/creation_form.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:flutter_test/flutter_test.dart';

CreationInput input({
  String title = 'Hades',
  String genre = 'Roguelike, Action',
  String platform = 'PC',
  String status = 'In Progress',
  bool owned = true,
  int interest = 8,
  String playtime = '0',
  String steamAppId = '',
  String imageUrl = 'https://img.example/h.jpg',
  String publisher = 'Supergiant Games',
  String mainStory = '22',
  String mainStoryWithExtras = '48',
  String completionist = '95',
  int reviewStars = 0,
  String review = '',
  String note = '',
}) => CreationInput(
  title: title,
  genre: genre,
  platform: platform,
  status: status,
  owned: owned,
  interest: interest,
  playtime: playtime,
  steamAppId: steamAppId,
  imageUrl: imageUrl,
  publisher: publisher,
  mainStory: mainStory,
  mainStoryWithExtras: mainStoryWithExtras,
  completionist: completionist,
  reviewStars: reviewStars,
  review: review,
  note: note,
);

const prefill = CreationPrefill(
  custom: false,
  title: 'Hades',
  imageUrl: 'https://img.example/h.jpg',
  description: 'Defy the god of the dead.',
  publisher: 'Supergiant Games',
  trailerUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
  genres: 'Roguelike, Action',
  platforms: 'PC, Switch',
  mainStory: 22,
  mainStoryWithExtras: 48,
  completionist: 95,
);

void main() {
  group('CreationPrefill.fromQuery', () {
    test('reads what the add-a-game sheet put into the address', () {
      final uri = Uri.parse(
        creationToolLocation(
          const GameSearchResult(
            id: 1,
            title: 'Hades',
            imageUrl: 'https://img.example/h.jpg',
            genres: ['Roguelike', 'Action'],
            platforms: ['PC', 'Switch'],
            mainStory: 22,
            mainStoryWithExtras: 48.5,
            completionist: 95,
            description: 'Defy the god of the dead.',
            publisher: 'Supergiant Games',
            trailerUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
          ),
        ),
      );

      final read = CreationPrefill.fromQuery(uri.queryParameters);

      expect(read.custom, isFalse);
      expect(read.title, 'Hades');
      expect(read.imageUrl, 'https://img.example/h.jpg');
      expect(read.genres, 'Roguelike, Action');
      expect(read.platformOptions, ['PC', 'Switch']);
      expect(read.mainStory, 22);
      expect(read.mainStoryWithExtras, 48.5);
      expect(read.publisher, 'Supergiant Games');
    });

    test('preselects PC (Microsoft Windows) when the game has it', () {
      final read = CreationPrefill.fromQuery({
        'platforms': 'PlayStation 5, PC (Microsoft Windows), Switch',
      });

      expect(read.defaultPlatform, 'PC (Microsoft Windows)');
    });

    test('preselects the first platform when PC is not offered', () {
      final read = CreationPrefill.fromQuery({
        'platforms': 'PlayStation 5, Switch',
      });

      expect(read.defaultPlatform, 'PlayStation 5');
      expect(CreationPrefill.fromQuery({}).defaultPlatform, '');
    });

    test('knows the custom mode', () {
      final read = CreationPrefill.fromQuery({'title': 'Mine', 'custom': '1'});

      expect(read.custom, isTrue);
      expect(read.title, 'Mine');
    });

    test('treats missing and unreadable numbers as zero', () {
      final read = CreationPrefill.fromQuery({
        'mainStory': 'abc',
        'completionist': '',
      });

      expect(read.mainStory, 0);
      expect(read.mainStoryWithExtras, 0);
      expect(read.completionist, 0);
    });

    test('names the Shared Space as the target', () {
      expect(
        CreationPrefill.fromQuery({'target': 'space'}).targetsSpace,
        isTrue,
      );
      expect(CreationPrefill.fromQuery({}).targetsSpace, isFalse);
    });
  });

  group('the missing data warning', () {
    test('is there without a cover or without beat times', () {
      expect(prefill.hasMissingData, isFalse);
      expect(
        CreationPrefill.fromQuery({'mainStory': '5', 'imageUrl': ''})
            .hasMissingData,
        isTrue,
      );
      expect(
        CreationPrefill.fromQuery({'imageUrl': 'https://x/y.jpg'})
            .hasMissingData,
        isTrue,
      );
    });

    test('says what was not found', () {
      expect(
        CreationPrefill.fromQuery({}).missingDataMessage,
        'No image found. No game beat times found. Consider searching for the '
        'game again in the searchbar to get complete data.',
      );
      expect(
        CreationPrefill.fromQuery({'imageUrl': 'https://x/y.jpg'})
            .missingDataMessage,
        'No game beat times found. Consider searching for the game again in '
        'the searchbar to get complete data.',
      );
    });
  });

  group('validateCreation', () {
    test('accepts a complete form', () {
      expect(validateCreation(input()), isNull);
    });

    test(
      'asks for a title, a genre, a platform and a status in that order',
      () {
        expect(validateCreation(input(title: '  ')), 'Please enter a title');
        expect(
          validateCreation(input(genre: ' , ')),
          'Please enter at least one genre',
        );
        expect(
          validateCreation(input(platform: '')),
          'Please select a platform',
        );
        expect(validateCreation(input(status: '')), 'Please select a status');
        expect(
          validateCreation(
            input(title: '', genre: '', platform: '', status: ''),
          ),
          'Please enter a title',
        );
      },
    );
  });

  group('resolvedSteamAppId', () {
    test('is a positive whole number', () {
      expect(resolvedSteamAppId('620'), 620);
      expect(resolvedSteamAppId(' 620 '), 620);
    });

    test('is nothing for anything else', () {
      expect(resolvedSteamAppId(''), isNull);
      expect(resolvedSteamAppId('0'), isNull);
      expect(resolvedSteamAppId('-5'), isNull);
      expect(resolvedSteamAppId('6.5'), isNull);
      expect(resolvedSteamAppId('abc'), isNull);
    });
  });

  group('effectivePlaytime', () {
    test('is what the user typed once they touched the field', () {
      expect(effectivePlaytime(touched: true, typed: '3', fromSteam: 40), '3');
    });

    test('is the Steam playtime until then', () {
      expect(
        effectivePlaytime(touched: false, typed: '0', fromSteam: 40.5),
        '40.5',
      );
      expect(
        effectivePlaytime(touched: false, typed: '0', fromSteam: 40),
        '40',
      );
    });

    test('is the typed text without a Steam playtime', () {
      expect(
        effectivePlaytime(touched: false, typed: '0', fromSteam: null),
        '0',
      );
    });
  });

  group('buildNewEntry', () {
    test('splits the lists and trims the text', () {
      final entry = buildNewEntry(
        input(
          title: '  Hades ',
          genre: 'Roguelike, Action ,',
          platform: 'PC',
          interest: 6,
          playtime: '12.5',
          steamAppId: '1145360',
        ),
        prefill,
      );

      expect(entry.title, 'Hades');
      expect(entry.genre, ['Roguelike', 'Action']);
      expect(entry.platform, ['PC']);
      expect(entry.interest, 6);
      expect(entry.playtime, 12.5);
      expect(entry.steamAppId, 1145360);
      expect(entry.imageLink, 'https://img.example/h.jpg');
    });

    test('takes description and trailer from the search', () {
      final entry = buildNewEntry(input(), prefill);

      expect(entry.description, 'Defy the god of the dead.');
      expect(entry.publisher, 'Supergiant Games');
      expect(entry.trailerLink, 'https://www.youtube.com/watch?v=abcdefghijk');
    });

    test('sends the publisher of the form, none when it is empty', () {
      expect(
        buildNewEntry(input(publisher: ' Supergiant '), prefill).publisher,
        'Supergiant',
      );
      expect(buildNewEntry(input(publisher: '  '), prefill).publisher, isNull);
    });

    test('withoutSteamAppId drops only the Steam App ID', () {
      final entry = buildNewEntry(input(steamAppId: '1145360'), prefill);

      final stripped = entry.withoutSteamAppId();

      expect(stripped.steamAppId, isNull);
      expect(stripped.title, entry.title);
      expect(stripped.platform, entry.platform);
      expect(stripped.publisher, entry.publisher);
      expect(stripped.mainTime, entry.mainTime);
    });

    test('sends only the beat times above zero', () {
      final entry = buildNewEntry(
        input(mainStory: '22', mainStoryWithExtras: '0', completionist: ''),
        prefill,
      );

      expect(entry.mainTime, 22);
      expect(entry.mainPlusExtraTime, isNull);
      expect(entry.completionTime, isNull);
    });

    test('leaves out an empty cover, review stars, review and note', () {
      final entry = buildNewEntry(
        input(imageUrl: '  ', reviewStars: 0, review: '', note: ''),
        prefill,
      );

      expect(entry.imageLink, isNull);
      expect(entry.reviewStars, isNull);
      expect(entry.review, isNull);
      expect(entry.note, isNull);
    });

    test('keeps a review, stars and a note', () {
      final entry = buildNewEntry(
        input(reviewStars: 9, review: 'Great', note: 'Replay'),
        prefill,
      );

      expect(entry.reviewStars, 9);
      expect(entry.review, 'Great');
      expect(entry.note, 'Replay');
    });

    test('treats an unreadable playtime as zero', () {
      expect(buildNewEntry(input(playtime: 'abc'), prefill).playtime, 0);
    });
  });

  group('CreationTarget.scopes', () {
    test('names the backlogs to create the entry in', () {
      expect(CreationTarget.personal.scopes(4), [null]);
      expect(CreationTarget.space.scopes(4), [4]);
      expect(CreationTarget.both.scopes(4), [null, 4]);
    });

    test('is always the personal backlog without an active space', () {
      for (final target in CreationTarget.values) {
        expect(target.scopes(null), [null]);
      }
    });
  });

  group('CreationPrefill.fromResult', () {
    test('is what the creation tool reads from the address of a result', () {
      const result = GameSearchResult(
        id: 1,
        title: 'Hades',
        imageUrl: 'https://img.example/h.jpg',
        genres: ['Roguelike'],
        platforms: ['PC', 'Switch'],
        mainStory: 22,
        mainStoryWithExtras: 48,
        completionist: 95,
        publisher: 'Supergiant Games',
      );

      final prefill = CreationPrefill.fromResult(result);

      expect(prefill.custom, isFalse);
      expect(prefill.title, 'Hades');
      expect(prefill.platformOptions, ['PC', 'Switch']);
      expect(prefill.mainStory, 22);
      expect(prefill.publisher, 'Supergiant Games');
    });

    test('keeps the whole description, which no address has to carry', () {
      final long = 'x' * 900;
      final prefill = CreationPrefill.fromResult(
        GameSearchResult(
          id: 1,
          title: 'Hades',
          genres: const [],
          platforms: const [],
          mainStory: 0,
          mainStoryWithExtras: 0,
          completionist: 0,
          description: long,
        ),
      );

      expect(prefill.description, long);
    });
  });
}
