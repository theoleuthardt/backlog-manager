import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/domain/filter_tokens.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fakes.dart';
import '../shell/shell_harness.dart';
import 'creation/creation_tool_page_test.dart' show openTool;
import 'inspector/entry_inspector_test.dart'
    show celeste, hades, openInspector, openTab;
import 'library/library_page_test.dart' show pumpLibrary;
import 'mobile_pages_test.dart' show found, resize;

const sizes = {
  'a phone in portrait': Size(402, 874),
  'a dense handheld': Size(732, 412),
};

const routes = [
  AppRoutes.home,
  AppRoutes.library,
  AppRoutes.steam,
  AppRoutes.import,
  AppRoutes.export,
  AppRoutes.appearance,
  AppRoutes.space,
  AppRoutes.settings,
];

final mobile = [isDesktopProvider.overrideWithValue(false)];

/// Every page and the main screens with data, with the larger text a user
/// can choose (1.3) and with every tap target at least 48x48 dp. The
/// inspector is scrolled back to its top before the check, because a target
/// that is cut by the edge of the scroll view counts with its visible part.
void main() {
  for (final MapEntry(key: device, value: size) in sizes.entries) {
    group('on $device', () {
      for (final route in routes) {
        testWidgets('$route has tap targets of at least 48 dp', (tester) async {
          final handle = tester.ensureSemantics();
          final app = await pumpApp(tester, size: size, desktop: false);
          await app.go(route);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          handle.dispose();
        });

        testWidgets('$route fits text scaled to 1.3', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final app = await pumpApp(tester, size: size, desktop: false);
          await app.go(route);
          expect(tester.takeException(), isNull);
        });
      }

      for (final scale in [1.0, 1.3]) {
        testWidgets('the library with games at text scale $scale', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpLibrary(
            tester,
            FakeBacklogApi(entries: const [hades, celeste]),
            overrides: mobile,
          );
          await resize(tester, size);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          handle.dispose();
        });

        testWidgets('the library with a filter at text scale $scale', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final container = await pumpLibrary(
            tester,
            FakeBacklogApi(entries: const [hades, celeste]),
            overrides: mobile,
          );
          container.read(filtersProvider.notifier).setList(FilterField.genre, [
            'Roguelike',
          ]);
          await resize(tester, size);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          handle.dispose();
        });

        testWidgets('the creation tool at text scale $scale', (tester) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await openTool(tester, overrides: mobile);
          await resize(tester, size);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          handle.dispose();
        });

        for (final tab in ['Details', 'Notes', 'Progress', 'Review']) {
          testWidgets('the $tab tab of the inspector at text scale $scale', (
            tester,
          ) async {
            final handle = tester.ensureSemantics();
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await openInspector(tester, overrides: mobile);
            await resize(tester, size);
            if (tab != 'Details') await openTab(tester, tab);
            await tester.drag(
              find
                  .descendant(
                    of: find.byKey(const Key('entry-inspector')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
              const Offset(0, 3000),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            handle.dispose();
          });
        }

        testWidgets('the add game sheet at text scale $scale', (tester) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final games = FakeGamesApi()
            ..onSearch = (term, deep) async => [found(1, 'Hades')];
          final container = await pumpLibrary(
            tester,
            FakeBacklogApi(entries: const [hades, celeste]),
            overrides: [gamesApiProvider.overrideWithValue(games), ...mobile],
          );
          await resize(tester, size);
          container.read(addGameRequestProvider.notifier).request();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          handle.dispose();
        });
      }
    });
  }
}
