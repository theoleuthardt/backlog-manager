import 'dart:convert';

import 'package:backlog_manager/domain/csv_import.dart';
import 'package:backlog_manager/domain/diff_fields.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> previewJson({
  int rowIndex = 0,
  String title = 'Hades',
  Object? playtime,
  Object? mainTime = '22.5',
  String? imageLink = 'https://img/hades.jpg',
  bool matched = true,
  List<Object?> duplicates = const [],
}) => {
  'row_index': rowIndex,
  'title': title,
  'genre': 'Roguelike',
  'platform': ['PC', 'Switch'],
  'status': 'Completed',
  'owned': true,
  'playtime': playtime,
  'review_stars': 9,
  'note': 'Great',
  'review': null,
  'completed_at': '2025-03-14T00:00:00Z',
  'image_link': imageLink,
  'description': 'Escape',
  'trailer_link': null,
  'main_time': mainTime,
  'main_plus_extra_time': '30',
  'completion_time': null,
  'matched': matched,
  'duplicates': duplicates,
};

CsvPreviewRow row({
  int rowIndex = 0,
  String? imageLink = 'https://img/a.jpg',
  double? mainTime = 10,
  bool matched = true,
  bool owned = false,
  List<CsvDuplicate> duplicates = const [],
}) => CsvPreviewRow(
  rowIndex: rowIndex,
  title: 'Game $rowIndex',
  genre: 'RPG',
  platform: const ['PC'],
  status: 'Playing',
  owned: owned,
  imageLink: imageLink,
  mainTime: mainTime,
  matched: matched,
  duplicates: duplicates,
);

const duplicate = CsvDuplicate(
  entryId: 5,
  title: 'Hades',
  diffs: [
    FieldDiffEntry(field: 'status', existing: 'Playing', proposed: 'Done'),
  ],
);

void main() {
  group('CsvColumnConfig', () {
    test('starts with the columns A to D and nothing optional', () {
      const config = CsvColumnConfig();

      expect(config.titleColumn, 'A');
      expect(config.genreColumn, 'B');
      expect(config.platformColumn, 'C');
      expect(config.statusColumn, 'D');
      expect(config.playtimeColumn, isNull);
      expect(config.ratingColumn, isNull);
      expect(config.completedAtColumn, isNull);
      expect(config.noteColumns, isEmpty);
      expect(config.reviewColumns, isEmpty);
    });

    test('copyWith changes one column and can clear an optional one', () {
      final config = const CsvColumnConfig(playtimeColumn: 'E')
          .copyWith(titleColumn: 'F', clearPlaytime: true, ratingColumn: 'G');

      expect(config.titleColumn, 'F');
      expect(config.playtimeColumn, isNull);
      expect(config.ratingColumn, 'G');
    });

    test('toggles a review or note column on and off', () {
      var config = const CsvColumnConfig().withReviewColumn('E', on: true);
      config = config.withReviewColumn('F', on: true);
      config = config.withNoteColumn('G', on: true);
      expect(config.reviewColumns, ['E', 'F']);
      expect(config.noteColumns, ['G']);

      config = config.withReviewColumn('E', on: false);
      expect(config.reviewColumns, ['F']);
    });
  });

  group('CsvPreviewRow.fromJson', () {
    test('reads the fields the backend sends, decimals as text', () {
      final parsed = CsvPreviewRow.fromJson(
        previewJson(rowIndex: 4, playtime: '12.5'),
      );

      expect(parsed.rowIndex, 4);
      expect(parsed.title, 'Hades');
      expect(parsed.genre, 'Roguelike');
      expect(parsed.platform, ['PC', 'Switch']);
      expect(parsed.status, 'Completed');
      expect(parsed.owned, isTrue);
      expect(parsed.playtime, 12.5);
      expect(parsed.reviewStars, 9);
      expect(parsed.note, 'Great');
      expect(parsed.review, isNull);
      expect(parsed.completedAt, DateTime.utc(2025, 3, 14));
      expect(parsed.imageLink, 'https://img/hades.jpg');
      expect(parsed.mainTime, 22.5);
      expect(parsed.mainPlusExtraTime, 30);
      expect(parsed.completionTime, isNull);
      expect(parsed.matched, isTrue);
    });

    test('reads numbers that arrive as numbers too', () {
      final parsed = CsvPreviewRow.fromJson(previewJson(mainTime: 8));

      expect(parsed.mainTime, 8);
    });

    test('reads the duplicates with their diffs', () {
      final parsed = CsvPreviewRow.fromJson(
        previewJson(
          duplicates: [
            {
              'backlog_entry_id': 5,
              'title': 'Hades',
              'diffs': [
                {'field': 'status', 'existing': 'Playing', 'proposed': 'Done'},
              ],
            },
          ],
        ),
      );

      expect(parsed.duplicates, hasLength(1));
      expect(parsed.duplicates.single.entryId, 5);
      expect(parsed.duplicates.single.title, 'Hades');
      expect(parsed.duplicates.single.diffs, [
        const FieldDiffEntry(
          field: 'status',
          existing: 'Playing',
          proposed: 'Done',
        ),
      ]);
    });
  });

  group('toSubmitJson', () {
    test('sends the fields as the backend expects them', () {
      final json = CsvPreviewRow.fromJson(previewJson(playtime: '12.5'))
          .toSubmitJson();

      expect(json['title'], 'Hades');
      expect(json['genre'], 'Roguelike');
      expect(json['platform'], ['PC', 'Switch']);
      expect(json['status'], 'Completed');
      expect(json['owned'], isTrue);
      expect(json['playtime'], '12.5');
      expect(json['review_stars'], 9);
      expect(json['note'], 'Great');
      expect(json['completed_at'], '2025-03-14T00:00:00.000Z');
      expect(json['image_link'], 'https://img/hades.jpg');
      expect(json['main_time'], '22.5');
      expect(json['main_plus_extra_time'], '30');
      expect(json['completion_time'], isNull);
      expect(json.containsKey('matched'), isFalse);
      expect(json.containsKey('row_index'), isFalse);
      expect(json.containsKey('duplicates'), isFalse);
    });

    test('writes whole hours without a decimal', () {
      final json = row(mainTime: 10).toSubmitJson();

      expect(json['main_time'], '10');
    });
  });

  group('editing', () {
    test('copyWith keeps every other field', () {
      final edited = row(rowIndex: 3).copyWith(title: 'Other', owned: true);

      expect(edited.title, 'Other');
      expect(edited.owned, isTrue);
      expect(edited.rowIndex, 3);
      expect(edited.genre, 'RPG');
    });

    test('platformsFromText splits at commas and drops empty parts', () {
      expect(platformsFromText('PC, Switch ,, '), ['PC', 'Switch']);
      expect(platformsFromText(''), isEmpty);
    });

    test('a wrong game replaces the game data and marks the row matched', () {
      final edited = applyWrongGame(
        row(rowIndex: 2, matched: false, mainTime: null, imageLink: null),
        const GameSearchResult(
          id: 1,
          title: 'Crash Bandicoot',
          genres: ['Platformer', 'Action'],
          platforms: ['PlayStation'],
          mainStory: 9,
          mainStoryWithExtras: 12,
          completionist: 20,
          imageUrl: 'https://img/crash.jpg',
          description: 'Spin',
          trailerUrl: 'https://youtu.be/x',
        ),
      );

      expect(edited.title, 'Crash Bandicoot');
      expect(edited.genre, 'Platformer, Action');
      expect(edited.imageLink, 'https://img/crash.jpg');
      expect(edited.description, 'Spin');
      expect(edited.trailerLink, 'https://youtu.be/x');
      expect(edited.mainTime, 9);
      expect(edited.mainPlusExtraTime, 12);
      expect(edited.completionTime, 20);
      expect(edited.matched, isTrue);
      expect(edited.platform, ['PC']);
      expect(edited.status, 'Playing');
    });

    test('a wrong game without genres keeps the genre of the row', () {
      final edited = applyWrongGame(
        row(),
        const GameSearchResult(
          id: 1,
          title: 'X',
          genres: [],
          platforms: [],
          mainStory: 1,
          mainStoryWithExtras: 1,
          completionist: 1,
        ),
      );

      expect(edited.genre, 'RPG');
      expect(edited.imageLink, isNull);
    });
  });

  group('the verdict of a row', () {
    test('a row that was not matched asks to check the match', () {
      final verdict = rowVerdict(row(matched: false));

      expect(verdict.chip, 'Check match');
      expect(verdict.action, RowAction.wrongGame);
    });

    test('a matched row without beat times says so', () {
      expect(rowVerdict(row(mainTime: null)).chip, 'No beat times');
      expect(rowVerdict(row(mainTime: null)).action, RowAction.cover);
    });

    test('a matched row without a cover says so', () {
      expect(rowVerdict(row(imageLink: null)).chip, 'No cover');
      expect(rowVerdict(row(imageLink: '')).chip, 'No cover');
    });

    test('an owned row with everything shows Owned', () {
      expect(rowVerdict(row(owned: true)).chip, 'Owned');
    });

    test('a complete row that is not owned has no chip', () {
      expect(rowVerdict(row()).chip, isNull);
      expect(rowVerdict(row()).action, RowAction.cover);
    });

    test('warnings list what is missing', () {
      expect(rowWarnings(row(imageLink: null, mainTime: null)), [
        'No cover found',
        'No beat times found',
      ]);
      expect(rowWarnings(row()), isEmpty);
    });
  });

  group('labels', () {
    test('the summary counts rows and the ones already in the backlog', () {
      final rows = [
        row(),
        row(rowIndex: 1, duplicates: [duplicate]),
        row(rowIndex: 2, duplicates: [duplicate]),
      ];

      expect(rowsSummary(rows), '3 rows - 2 already in your backlog');
      expect(rowsSummary([row()]), '1 row');
      expect(rowsSummary([]), '0 rows');
    });

    test('the import button follows the number of rows', () {
      expect(importLabel(294), 'Import 294 games');
      expect(importLabel(1), 'Import 1 game');
      expect(importLabel(0), 'Import 0 games');
    });

    test('progress labels', () {
      expect(previewLabel(null, null), 'Loading preview...');
      expect(previewLabel(3, 10), 'Loading 3/10...');
      expect(submitLabel(null, null), 'Importing...');
      expect(submitLabel(3, 10), 'Importing 3/10...');
    });

    test('the result toast names created and skipped rows', () {
      expect(importResultMessage(12, 0), 'Imported 12 backlog entries');
      expect(importResultMessage(1, 0), 'Imported 1 backlog entry');
      expect(
        importResultMessage(3, 2),
        'Imported 3 backlog entries, skipped 2',
      );
    });

    test('the skipped heading', () {
      expect(skippedHeading(1), '1 row skipped during import');
      expect(skippedHeading(4), '4 rows skipped during import');
    });

    test('a column shows its letter and its header', () {
      const headers = {'A': 'Game', 'B': ''};
      expect(columnLabel('A', headers), 'A: Game');
      expect(columnLabel('B', headers), 'B');
      expect(columnLabel('C', headers), 'C');
    });

    test('the letters are in spreadsheet order', () {
      expect(sortedColumnLetters({'AA': 'x', 'B': 'y', 'A': 'z', 'Z': 'w'}), [
        'A',
        'B',
        'Z',
        'AA',
      ]);
    });

    test('the completed month', () {
      expect(completedMonthLabel(DateTime.utc(2025, 3, 14)), 'March 2025');
    });

    test('the meta line of a row', () {
      expect(rowMeta(row()), 'RPG · PC · Playing');
      expect(rowMeta(row().copyWith(genre: '', platform: const [])), 'Playing');
    });
  });

  group('decodeCsvFile', () {
    String message(void Function() body) {
      try {
        body();
      } on CsvFileException catch (error) {
        return error.message;
      }
      return 'no error';
    }

    test('returns the text of a CSV file', () {
      expect(decodeCsvFile('games.csv', utf8.encode('a,b\n1,2')), 'a,b\n1,2');
    });

    test('accepts an upper case extension', () {
      expect(decodeCsvFile('GAMES.CSV', utf8.encode('a')), 'a');
    });

    test('drops a byte order mark', () {
      expect(
        decodeCsvFile('g.csv', [0xEF, 0xBB, 0xBF, ...utf8.encode('Titel')]),
        'Titel',
      );
    });

    test('refuses other files', () {
      expect(
        message(() => decodeCsvFile('games.txt', utf8.encode('a'))),
        'Choose a .csv file.',
      );
    });

    test('refuses an empty file', () {
      expect(message(() => decodeCsvFile('a.csv', [])), 'That file is empty.');
    });

    test('refuses a file that is too large', () {
      expect(
        message(() => decodeCsvFile('a.csv', List.filled(maxCsvBytes + 1, 97))),
        'That file is too large (10 MB at most).',
      );
    });

    test('refuses bytes that are not UTF-8', () {
      expect(
        message(() => decodeCsvFile('a.csv', [0xFF, 0xFE, 0x00, 0xD8])),
        'That file is not valid UTF-8 text.',
      );
    });
  });
}
