import 'dart:async';
import 'dart:convert';

import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/csv_import_api.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/csv_import.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/platform/csv_file_picker.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../settings/settings_page_test.dart' show openSettings;

class FakeCsvImportApi implements CsvImportApi {
  Map<String, String> headersResult = {
    'A': 'Game',
    'B': 'Genre',
    'C': 'Platform',
    'D': 'Status',
    'E': 'Hours',
  };
  Object? headersError;
  final headerCalls = <String>[];
  final previews = <CsvColumnConfig>[];
  final submits = <List<CsvPreviewRow>>[];
  late StreamController<SseEvent> previewStream;
  late StreamController<SseEvent> submitStream;
  bool previewCancelled = false;
  bool submitCancelled = false;

  @override
  Future<Map<String, String>> headers(String content) async {
    headerCalls.add(content);
    if (headersError != null) throw headersError!;
    return headersResult;
  }

  @override
  Stream<SseEvent> preview(String content, CsvColumnConfig config) {
    previews.add(config);
    previewStream = StreamController<SseEvent>(
      onCancel: () => previewCancelled = true,
    );
    return previewStream.stream;
  }

  @override
  Stream<SseEvent> submit(List<CsvPreviewRow> rows) {
    submits.add(rows);
    submitStream = StreamController<SseEvent>(
      onCancel: () => submitCancelled = true,
    );
    return submitStream.stream;
  }
}

class FakeCsvFilePicker implements CsvFilePicker {
  PickedFile? next;

  @override
  Future<PickedFile?> pick() async => next;
}

PickedFile pickedBytes(String name, List<int> bytes) =>
    PickedFile(name: name, readBytes: () async => bytes);

PickedFile csvFile({
  String name = 'backlog-2025.csv',
  String text = 'a,b\n1,2',
}) => pickedBytes(name, utf8.encode(text));

Map<String, Object?> previewJson(
  int rowIndex,
  String title, {
  bool matched = true,
  bool owned = false,
  String? imageLink = 'https://img/x.jpg',
  Object? mainTime = '10',
  List<Object?> duplicates = const [],
}) => {
  'row_index': rowIndex,
  'title': title,
  'genre': 'RPG',
  'platform': ['PC'],
  'status': 'Playing',
  'owned': owned,
  'playtime': '12.5',
  'review_stars': 8,
  'note': null,
  'review': null,
  'completed_at': '2025-03-14T00:00:00',
  'image_link': imageLink,
  'description': null,
  'trailer_link': null,
  'main_time': mainTime,
  'main_plus_extra_time': null,
  'completion_time': null,
  'matched': matched,
  'duplicates': duplicates,
};

class Opened {
  Opened(this.api, this.picker, this.games, this.backlog);

  final FakeCsvImportApi api;
  final FakeCsvFilePicker picker;
  final FakeGamesApi games;
  final FakeBacklogApi backlog;
}

Future<Opened> open(
  WidgetTester tester, {
  void Function(FakeCsvImportApi api)? setUp,
}) async {
  final api = FakeCsvImportApi();
  setUp?.call(api);
  final picker = FakeCsvFilePicker()..next = csvFile();
  final games = FakeGamesApi();
  final backlog = FakeBacklogApi();
  await openSettings(
    tester,
    location: '/import',
    overrides: [
      csvImportApiProvider.overrideWithValue(api),
      csvFilePickerProvider.overrideWithValue(picker),
      gamesApiProvider.overrideWithValue(games),
      backlogApiProvider.overrideWithValue(backlog),
    ],
  );
  return Opened(api, picker, games, backlog);
}

Future<void> chooseFile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('import-choose')));
  await tester.pumpAndSettle();
}

Future<void> startPreview(WidgetTester tester, Opened opened) async {
  await tester.tap(find.byKey(const Key('import-preview')));
  await tester.pump();
}

Future<Opened> previewed(
  WidgetTester tester, {
  List<Map<String, Object?>>? rows,
}) async {
  final opened = await open(tester);
  await chooseFile(tester);
  await startPreview(tester, opened);
  opened.api.previewStream.add(
    SseDone(
      rows ??
          [
            previewJson(0, 'Hades', owned: true),
            previewJson(1, 'Celeste', matched: false),
            previewJson(2, 'Portal', mainTime: null),
          ],
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Future<void> dismissToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 6));

void main() {
  group('choosing a file', () {
    testWidgets('starts with the explanation and the choose button', (
      tester,
    ) async {
      await open(tester);

      expect(find.byKey(const Key('page-import')), findsOneWidget);
      expect(find.text('Import backlog from CSV'), findsOneWidget);
      expect(find.text('Choose CSV file...'), findsOneWidget);
      expect(find.textContaining('drop a .csv file'), findsOneWidget);
    });

    testWidgets('reads the headers and shows the column mapping', (
      tester,
    ) async {
      final opened = await open(tester);

      await chooseFile(tester);

      expect(opened.api.headerCalls, ['a,b\n1,2']);
      expect(find.text('backlog-2025.csv'), findsOneWidget);
      expect(find.text('Column mapping'), findsOneWidget);
      expect(find.text('A: Game'), findsOneWidget);
      expect(find.text('B: Genre'), findsOneWidget);
      expect(find.text('C: Platform'), findsOneWidget);
      expect(find.text('D: Status'), findsOneWidget);
      expect(find.text('Preview import'), findsOneWidget);
    });

    testWidgets('does nothing when the dialog is cancelled', (tester) async {
      final opened = await open(tester);
      opened.picker.next = null;

      await chooseFile(tester);

      expect(opened.api.headerCalls, isEmpty);
      expect(find.text('Choose CSV file...'), findsOneWidget);
    });

    testWidgets('refuses a file that is not a CSV file', (tester) async {
      final opened = await open(tester);
      opened.picker.next = csvFile(name: 'games.txt');

      await chooseFile(tester);

      expect(find.text('Choose a .csv file.'), findsOneWidget);
      expect(opened.api.headerCalls, isEmpty);
      await dismissToast(tester);
    });

    testWidgets('refuses a file that is not valid text', (tester) async {
      final opened = await open(tester);
      opened.picker.next = pickedBytes('bad.csv', [0xFF, 0xFE, 0x00, 0xD8]);

      await chooseFile(tester);

      expect(find.text('That file is not valid UTF-8 text.'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('shows the error when the headers cannot be read', (
      tester,
    ) async {
      await open(tester, setUp: (api) => api.headersError = Exception('boom'));

      await chooseFile(tester);

      expect(find.text('Failed to read CSV headers'), findsOneWidget);
      expect(find.text('Choose CSV file...'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('Choose another file replaces the file', (tester) async {
      final opened = await open(tester);
      await chooseFile(tester);
      opened.picker.next = csvFile(name: 'other.csv', text: 'x,y');

      await tester.tap(find.byKey(const Key('import-choose-other')));
      await tester.pumpAndSettle();

      expect(find.text('other.csv'), findsOneWidget);
      expect(opened.api.headerCalls, ['a,b\n1,2', 'x,y']);
    });

    testWidgets('Cancel goes back to the start', (tester) async {
      await open(tester);
      await chooseFile(tester);

      await tester.tap(find.byKey(const Key('import-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Import backlog from CSV'), findsOneWidget);
    });
  });

  group('the column mapping', () {
    testWidgets('previews with the default columns', (tester) async {
      final opened = await open(tester);
      await chooseFile(tester);

      await startPreview(tester, opened);

      final config = opened.api.previews.single;
      expect(config.titleColumn, 'A');
      expect(config.genreColumn, 'B');
      expect(config.platformColumn, 'C');
      expect(config.statusColumn, 'D');
      expect(config.playtimeColumn, isNull);
      await opened.api.previewStream.close();
      await tester.pumpAndSettle();
      await dismissToast(tester);
    });

    testWidgets('previews with the chosen columns', (tester) async {
      final opened = await open(tester);
      await chooseFile(tester);

      await tester.tap(find.byKey(const Key('import-column-playtime')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('E: Hours').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import-Review columns-E')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import-Note columns-B')));
      await tester.pumpAndSettle();
      await startPreview(tester, opened);

      final config = opened.api.previews.single;
      expect(config.playtimeColumn, 'E');
      expect(config.reviewColumns, ['E']);
      expect(config.noteColumns, ['B']);
      await opened.api.previewStream.close();
      await tester.pumpAndSettle();
      await dismissToast(tester);
    });

    testWidgets('an optional column can be set back to none', (tester) async {
      final opened = await open(tester);
      await chooseFile(tester);
      await tester.tap(find.byKey(const Key('import-column-rating')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('E: Hours').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('import-column-rating')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('-- none --').last);
      await tester.pumpAndSettle();
      await startPreview(tester, opened);

      expect(opened.api.previews.single.ratingColumn, isNull);
      await opened.api.previewStream.close();
      await tester.pumpAndSettle();
      await dismissToast(tester);
    });
  });

  group('the preview', () {
    testWidgets('shows the progress and a cancel that stops it', (
      tester,
    ) async {
      final opened = await open(tester);
      await chooseFile(tester);
      await startPreview(tester, opened);
      expect(find.text('Loading preview...'), findsOneWidget);

      opened.api.previewStream.add(const SseProgress(2, 5));
      await tester.pump();
      expect(find.text('Loading 2/5...'), findsOneWidget);

      await tester.tap(find.byKey(const Key('import-cancel')));
      await tester.pumpAndSettle();

      expect(opened.api.previewCancelled, isTrue);
      expect(find.text('Preview cancelled'), findsOneWidget);
      expect(find.text('Preview import'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('lists the rows with their results', (tester) async {
      await previewed(tester);

      expect(find.text('Hades'), findsOneWidget);
      expect(find.text('Celeste'), findsOneWidget);
      expect(find.text('Portal'), findsOneWidget);
      expect(find.text('RPG · PC · Playing'), findsNWidgets(3));
      expect(find.byKey(const Key('import-chip-0')), findsOneWidget);
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('Check match'), findsOneWidget);
      expect(find.text('No beat times'), findsOneWidget);
      expect(find.text('Wrong game'), findsOneWidget);
      expect(find.text('Cover'), findsNWidgets(2));
      expect(find.text('3 rows'), findsOneWidget);
      expect(find.text('Import 3 games'), findsOneWidget);
    });

    testWidgets('shows the info line of a row', (tester) async {
      await previewed(tester);

      expect(find.text('12.5 h played'), findsNWidgets(3));
      expect(find.text('Rating: 8/10'), findsNWidgets(3));
      expect(find.text('Completed: March 2025'), findsNWidgets(3));
      expect(find.text('No beat times found'), findsOneWidget);
    });

    testWidgets('warns about a missing cover', (tester) async {
      await previewed(tester, rows: [previewJson(0, 'Hades', imageLink: null)]);

      expect(find.text('No cover found'), findsOneWidget);
      expect(find.text('No cover'), findsOneWidget);
    });

    testWidgets('says so when there is no row to preview', (tester) async {
      await previewed(tester, rows: []);

      expect(
        find.text('No rows with a title found to preview'),
        findsOneWidget,
      );
      await dismissToast(tester);
    });

    testWidgets('shows the message of the server when it fails', (
      tester,
    ) async {
      final opened = await open(tester);
      await chooseFile(tester);
      await startPreview(tester, opened);

      opened.api.previewStream.add(const SseError('IGDB is unreachable'));
      await tester.pumpAndSettle();

      expect(find.text('IGDB is unreachable'), findsOneWidget);
      expect(find.text('Preview import'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('counts the rows that are already in the backlog', (
      tester,
    ) async {
      await previewed(
        tester,
        rows: [
          previewJson(
            0,
            'Hades',
            duplicates: [
              {
                'backlog_entry_id': 5,
                'title': 'Hades',
                'diffs': [
                  {
                    'field': 'status',
                    'existing': 'Playing',
                    'proposed': 'Completed',
                  },
                ],
              },
            ],
          ),
          previewJson(1, 'Celeste'),
        ],
      );

      expect(find.text('2 rows - 1 already in your backlog'), findsOneWidget);
      expect(find.text('Already in your backlog (1)'), findsOneWidget);
      expect(find.byKey(const Key('diff-status-old')), findsNothing);

      await tester.tap(find.byKey(const Key('import-duplicates-0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diff-status-old')), findsOneWidget);
      expect(find.byKey(const Key('diff-status-new')), findsOneWidget);
    });

    testWidgets('removing a row lowers the number to import', (tester) async {
      await previewed(tester);

      await tester.tap(find.byKey(const Key('import-remove-1')));
      await tester.pumpAndSettle();

      expect(find.text('Celeste'), findsNothing);
      expect(find.text('Import 2 games'), findsOneWidget);
    });

    testWidgets('stays fast with a thousand rows', (tester) async {
      await previewed(
        tester,
        rows: [for (var i = 0; i < 1000; i++) previewJson(i, 'Game $i')],
      );

      expect(find.text('Import 1000 games'), findsOneWidget);
      expect(find.text('Game 0'), findsOneWidget);
      expect(find.text('Game 999'), findsNothing);
    });
  });

  group('editing a row', () {
    testWidgets('changes the title, genre, platform, status and owned', (
      tester,
    ) async {
      final opened = await previewed(tester, rows: [previewJson(0, 'Hades')]);

      await tester.tap(find.byKey(const Key('import-edit-0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('import-row-title')),
        'Hades II',
      );
      await tester.enterText(
        find.byKey(const Key('import-row-genre')),
        'Action',
      );
      await tester.enterText(
        find.byKey(const Key('import-row-platform')),
        'PC, Switch',
      );
      await tester.tap(find.byKey(const Key('import-row-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import-row-owned')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import-row-done')));
      await tester.pumpAndSettle();

      expect(find.text('Hades II'), findsOneWidget);
      expect(find.text('Action · PC, Switch · Completed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('import-submit')));
      await tester.pump();
      final row = opened.api.submits.single.single;
      expect(row.title, 'Hades II');
      expect(row.genre, 'Action');
      expect(row.platform, ['PC', 'Switch']);
      expect(row.status, 'Completed');
      expect(row.owned, isTrue);
      opened.api.submitStream.add(
        const SseDone({'created': <Object?>[], 'skipped': <Object?>[]}),
      );
      await tester.pumpAndSettle();
      await dismissToast(tester);
    });

    testWidgets('removes the row from the import', (tester) async {
      await previewed(tester);

      await tester.tap(find.byKey(const Key('import-edit-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from import'));
      await tester.pumpAndSettle();

      expect(find.text('Hades'), findsNothing);
      expect(find.text('Import 2 games'), findsOneWidget);
    });

    testWidgets('Wrong game replaces the data and marks the row matched', (
      tester,
    ) async {
      final opened = await previewed(
        tester,
        rows: [previewJson(0, 'Crash', matched: false, mainTime: null)],
      );
      opened.games.onSearch = (term, deep) async => [
        const GameSearchResult(
          id: 7,
          title: 'Crash Bandicoot',
          genres: ['Platformer'],
          platforms: ['PlayStation'],
          mainStory: 9,
          mainStoryWithExtras: 12,
          completionist: 20,
          imageUrl: 'https://img/crash.jpg',
        ),
      ];

      await tester.tap(find.byKey(const Key('import-action-0')));
      await tester.pumpAndSettle();
      expect(opened.games.calls, contains('search Crash'));
      await tester.tap(find.text('Crash Bandicoot'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wrong-use')));
      await tester.pumpAndSettle();

      expect(find.text('Crash Bandicoot'), findsOneWidget);
      expect(find.text('Check match'), findsNothing);
      expect(find.text('Platformer · PC · Playing'), findsOneWidget);
      expect(find.text('Cover'), findsOneWidget);
    });
  });

  group('importing', () {
    testWidgets('sends the rows of the preview and reports the result', (
      tester,
    ) async {
      final opened = await previewed(tester);

      await tester.tap(find.byKey(const Key('import-submit')));
      await tester.pump();
      expect(find.text('Importing...'), findsOneWidget);
      opened.api.submitStream.add(const SseProgress(1, 3));
      await tester.pump();
      expect(find.text('Importing 1/3...'), findsOneWidget);

      expect(opened.api.submits.single.map((r) => r.title), [
        'Hades',
        'Celeste',
        'Portal',
      ]);
      final entriesBefore = opened.backlog.calls
          .where((c) => c.startsWith('entries'))
          .length;
      opened.api.submitStream.add(
        const SseDone({
          'created': <Object?>[<String, Object?>{}, <String, Object?>{}],
          'skipped': [
            {'title': 'Portal', 'reason': 'Already exists'},
          ],
        }),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Imported 2 backlog entries, skipped 1'),
        findsOneWidget,
      );
      expect(find.text('Import backlog from CSV'), findsOneWidget);
      expect(find.text('1 row skipped during import'), findsOneWidget);
      expect(find.text('Already exists'), findsNothing);
      await tester.tap(find.byKey(const Key('import-skipped-toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Already exists'), findsOneWidget);
      expect(find.textContaining('Portal'), findsWidgets);
      await dismissToast(tester);
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(routerProvider)
          .go(AppRoutes.library);
      await tester.pumpAndSettle();
      expect(
        opened.backlog.calls.where((c) => c.startsWith('entries')).length,
        greaterThan(entriesBefore),
      );
    });

    testWidgets('Cancel stops the import', (tester) async {
      final opened = await previewed(tester);
      await tester.tap(find.byKey(const Key('import-submit')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('import-cancel')));
      await tester.pumpAndSettle();

      expect(opened.api.submitCancelled, isTrue);
      expect(find.text('Import cancelled'), findsOneWidget);
      expect(find.text('Import 3 games'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('keeps the preview when the import fails', (tester) async {
      final opened = await previewed(tester);
      await tester.tap(find.byKey(const Key('import-submit')));
      await tester.pump();

      opened.api.submitStream.add(const SseError('Import failed'));
      await tester.pumpAndSettle();

      expect(find.text('Import failed'), findsOneWidget);
      expect(find.text('Import 3 games'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('the import button is off while a request runs', (
      tester,
    ) async {
      final opened = await previewed(tester);
      await tester.tap(find.byKey(const Key('import-submit')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('import-submit')));
      await tester.pump();

      expect(opened.api.submits, hasLength(1));
      await opened.api.submitStream.close();
      await tester.pumpAndSettle();
      await dismissToast(tester);
    });

    testWidgets('Escape does not leave the page while importing', (
      tester,
    ) async {
      final opened = await previewed(tester);
      await tester.tap(find.byKey(const Key('import-submit')));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byKey(const Key('page-import')), findsOneWidget);
      await opened.api.submitStream.close();
      await tester.pumpAndSettle();
      await dismissToast(tester);
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the import preview in $themeId', tags: 'golden', (
      tester,
    ) async {
      await previewed(
        tester,
        rows: [
          previewJson(0, 'Hades', owned: true),
          previewJson(1, 'Celeste', matched: false),
          previewJson(2, 'Portal', mainTime: null),
          previewJson(3, 'A Way Out', imageLink: null),
          previewJson(
            4,
            'Untitled Goose Game',
            duplicates: [
              {
                'backlog_entry_id': 5,
                'title': 'Untitled Goose Game',
                'diffs': <Object?>[],
              },
            ],
          ),
        ],
      );
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(themeIdProvider.notifier)
          .select(themeId);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/import_preview_$themeId.png'),
      );
    });
  }
}
