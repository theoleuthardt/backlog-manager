import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/add_game/add_game_sheet.dart';
import 'package:backlog_manager/features/import_csv/csv_preview_table.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fakes.dart';
import '../shell/shell_harness.dart';
import 'creation/creation_tool_page_test.dart' show openTool;
import 'import_csv/import_csv_page_test.dart' as csv;
import 'inspector/entry_inspector_test.dart'
    show celeste, hades, openInspector, openTab;
import 'library/library_page_test.dart' show pumpLibrary;
import 'space/space_page_test.dart' as space;

const sizes = {
  'a phone in portrait': Size(402, 874),
  'a phone in landscape': Size(874, 402),
  'a dense handheld': Size(732, 412),
  'a large handheld': Size(960, 540),
};

final mobile = [isDesktopProvider.overrideWithValue(false)];

/// The pages are opened at the desktop size their helpers use and then the
/// window takes the size of the device, the way a turned device would.
Future<void> resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

GameSearchResult found(int id, String title) => GameSearchResult(
  id: id,
  title: title,
  genres: const ['Roguelike', 'Action'],
  platforms: const ['PC', 'Switch'],
  mainStory: 22,
  mainStoryWithExtras: 48,
  completionist: 95,
);

void main() {
  for (final MapEntry(key: device, value: size) in sizes.entries) {
    group('on $device', () {
      for (final route in [
        AppRoutes.home,
        AppRoutes.library,
        AppRoutes.steam,
        AppRoutes.import,
        AppRoutes.export,
        AppRoutes.appearance,
        AppRoutes.space,
        AppRoutes.settings,
        AppRoutes.signIn,
        AppRoutes.setup,
      ]) {
        testWidgets('$route fits the screen', (tester) async {
          final app = await pumpApp(tester, size: size, desktop: false);
          await app.go(route);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('the library with games fits the screen', (tester) async {
        await pumpLibrary(
          tester,
          FakeBacklogApi(entries: const [hades, celeste]),
          overrides: mobile,
        );
        await resize(tester, size);

        expect(find.byKey(const Key('page-library')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the invite form of the space fits the screen', (
        tester,
      ) async {
        await space.open(tester, space.noSpace, overrides: mobile);
        await resize(tester, size);

        expect(find.byKey(const Key('space-invite-send')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a row of the CSV preview keeps room for the title', (
        tester,
      ) async {
        final opened = await csv.open(tester, desktop: false);
        await resize(tester, size);
        await csv.chooseFile(tester);
        await tester.ensureVisible(find.byKey(const Key('import-preview')));
        await csv.startPreview(tester, opened);
        opened.api.previewStream.add(
          SseDone([
            csv.previewJson(0, 'Hades', owned: true),
            csv.previewJson(1, 'Celeste', matched: false),
          ]),
        );
        await tester.pumpAndSettle();

        final title = tester.getSize(find.byKey(const Key('import-edit-0')));
        final row = tester.getSize(find.byType(CsvRowTile).first);
        expect(title.width, greaterThan(row.width / 2));
        expect(find.byKey(const Key('import-chip-0')), findsOneWidget);
        expect(find.byKey(const Key('import-action-0')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the column mapping of the CSV import stays reachable', (
        tester,
      ) async {
        final opened = await csv.open(tester, desktop: false);
        await resize(tester, size);
        await csv.chooseFile(tester);
        await tester.ensureVisible(find.byKey(const Key('import-preview')));
        await csv.startPreview(tester, opened);
        opened.api.previewStream.add(
          SseDone([csv.previewJson(0, 'Hades', owned: true)]),
        );
        await tester.pumpAndSettle();

        final mapping = find.byKey(const Key('import-mapping'));
        if (mapping.evaluate().isNotEmpty) {
          await tester.tap(mapping);
          await tester.pumpAndSettle();
        }
        final preview = find.byKey(const Key('import-preview'));
        await tester.ensureVisible(preview);
        await tester.pumpAndSettle();
        await tester.tap(preview);
        await tester.pump();

        expect(opened.api.previews, hasLength(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the creation tool fits the screen', (tester) async {
        await openTool(tester, overrides: mobile);
        await resize(tester, size);

        expect(find.byKey(const Key('creation-submit')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the cover of the creation tool stays small', (tester) async {
        await openTool(tester, overrides: mobile);
        await resize(tester, size);

        final cover = find.descendant(
          of: find.byKey(const Key('page-creation')),
          matching: find.byType(ShelfCover),
        );
        expect(tester.getSize(cover.first).width, lessThanOrEqualTo(180));
      });

      testWidgets('the batch of the creation tool fits the screen', (
        tester,
      ) async {
        await openTool(
          tester,
          overrides: mobile,
          location: batchCreationLocation([
            'Hades',
            'A game whose title is long enough to need the whole row',
          ]),
          setUp: (api, games) =>
              games.onSearch = (term, deep) async =>
                  term == 'Hades' ? [found(1, 'Hades')] : const [],
        );
        await resize(tester, size);
        await tester.tap(find.byKey(const Key('batch-toggle-0')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch-item-1')), findsOneWidget);
        expect(find.byKey(const Key('creation-title')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the batch mode of the add game sheet fits the screen', (
        tester,
      ) async {
        await pumpLibrary(
          tester,
          FakeBacklogApi(entries: const [hades]),
          overrides: mobile,
        );
        await resize(tester, size);
        await tester.tap(find.text('Add Game').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Batch'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('add-batch-titles')),
          'Hades\nCeleste',
        );
        await tester.pumpAndSettle();

        expect(find.text('2 games'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      for (final tab in ['Details', 'Notes', 'Progress', 'Review', 'Trailer']) {
        testWidgets('the $tab tab of the inspector fits the screen', (
          tester,
        ) async {
          await openInspector(tester, overrides: mobile);
          await resize(tester, size);
          if (tab != 'Details') await openTab(tester, tab);

          expect(find.byKey(const Key('entry-inspector')), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('the add game sheet with results fits the screen', (
        tester,
      ) async {
        final games = FakeGamesApi()
          ..onSearch = (term, deep) async => [
            found(1, 'Hades'),
            found(2, 'Hades II'),
            found(3, 'Hades Star'),
          ];
        final container = await pumpLibrary(
          tester,
          FakeBacklogApi(entries: const [hades, celeste]),
          overrides: [gamesApiProvider.overrideWithValue(games), ...mobile],
        );
        await resize(tester, size);
        container.read(addGameRequestProvider.notifier).request();
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AddGameSheet),
            matching: find.byType(TextField),
          ),
          'hades',
        );
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();

        expect(find.text('Hades II'), findsOneWidget);
        expect(find.byKey(const Key('add-continue')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('the library header', () {
    Future<void> scrollLibrary(WidgetTester tester) async {
      await tester.drag(
        find.byKey(const Key('page-library')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    }

    final many = [
      for (var id = 1; id <= 12; id++)
        BacklogEntry(id: id, title: 'Game $id', status: 'In Progress'),
    ];

    testWidgets('scrolls away with the games on a handheld', (tester) async {
      await pumpLibrary(
        tester,
        FakeBacklogApi(entries: many),
        overrides: mobile,
      );
      await resize(tester, sizes['a dense handheld']!);
      final before = tester.getTopLeft(find.byKey(const Key('filter-bar'))).dy;

      await scrollLibrary(tester);

      final filter = find.byKey(const Key('filter-bar'));
      expect(
        filter.evaluate().isEmpty || tester.getTopLeft(filter).dy < before,
        isTrue,
      );
    });

    testWidgets('stays in place on the desktop', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: many), height: 700);
      final before = tester.getTopLeft(find.byKey(const Key('filter-bar'))).dy;

      await scrollLibrary(tester);

      expect(tester.getTopLeft(find.byKey(const Key('filter-bar'))).dy, before);
    });
  });

  group('goldens', () {
    for (final (name, size) in [
      ('phone', sizes['a phone in portrait']!),
      ('handheld', sizes['a dense handheld']!),
    ]) {
      testWidgets('the library on a $name', tags: 'golden', (tester) async {
        await pumpLibrary(
          tester,
          FakeBacklogApi(entries: const [hades, celeste]),
          overrides: mobile,
        );
        await resize(tester, size);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/mobile_library_$name.png'),
        );
      });

      testWidgets('the inspector on a $name', tags: 'golden', (tester) async {
        await openInspector(tester, overrides: mobile);
        await resize(tester, size);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/mobile_inspector_$name.png'),
        );
      });
    }

    testWidgets('the settings tabs on a phone', tags: 'golden', (tester) async {
      final app = await pumpApp(
        tester,
        size: sizes['a phone in portrait']!,
        desktop: false,
      );
      await app.go(AppRoutes.settings);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_settings_phone.png'),
      );
    });

    testWidgets('the appearance page on a phone', tags: 'golden', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        size: sizes['a phone in portrait']!,
        desktop: false,
      );
      await app.go(AppRoutes.appearance);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_appearance_phone.png'),
      );
    });

    testWidgets('the add game sheet on a phone', tags: 'golden', (
      tester,
    ) async {
      final games = FakeGamesApi()
        ..onSearch = (term, deep) async => [
          found(1, 'Hades'),
          found(2, 'Hades II'),
        ];
      final container = await pumpLibrary(
        tester,
        FakeBacklogApi(entries: const [hades, celeste]),
        overrides: [gamesApiProvider.overrideWithValue(games), ...mobile],
      );
      await resize(tester, sizes['a phone in portrait']!);
      container.read(addGameRequestProvider.notifier).request();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AddGameSheet),
          matching: find.byType(TextField),
        ),
        'hades',
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_add_game_phone.png'),
      );
    });
  });
}
