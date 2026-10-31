import 'package:backlog_manager/platform/desktop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../inspector/entry_inspector_test.dart' show celeste, hades;
import '../mobile_pages_test.dart' show resize;
import 'library_page_test.dart' show pumpLibrary;

const phone = Size(402, 874);

Future<FakeBacklogApi> openOnPhone(WidgetTester tester) async {
  final api = FakeBacklogApi(entries: const [hades, celeste]);
  await pumpLibrary(
    tester,
    api,
    overrides: [isDesktopProvider.overrideWithValue(false)],
  );
  await resize(tester, phone);
  return api;
}

Finder tile(int id) => find.byKey(Key('library-tile-$id'));

Finder menuItem(String label) => find.widgetWithText(MenuItemButton, label);

Finder submenu(String label) => find.widgetWithText(SubmenuButton, label);

void main() {
  group('on a touch screen', () {
    testWidgets('a long press opens the menu of the game', (tester) async {
      await openOnPhone(tester);

      await tester.longPress(tile(1));
      await tester.pumpAndSettle();

      expect(menuItem('Open Details'), findsOneWidget);
      expect(menuItem('Select'), findsOneWidget);
      expect(submenu('Move to status'), findsOneWidget);
    });

    testWidgets('Select in the menu starts the selection, a tap adds a game', (
      tester,
    ) async {
      await openOnPhone(tester);

      await tester.longPress(tile(1));
      await tester.pumpAndSettle();
      await tester.tap(menuItem('Select'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('selection-bar')), findsOneWidget);

      await tester.scrollUntilVisible(
        tile(2),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('page-library')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(tile(2));
      await tester.pumpAndSettle();
      await tester.tap(tile(2));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('Move to status moves the game without dragging', (
      tester,
    ) async {
      final api = await openOnPhone(tester);

      await tester.longPress(tile(1));
      await tester.pumpAndSettle();
      await tester.tap(submenu('Move to status'));
      await tester.pumpAndSettle();
      await tester.tap(menuItem('Completed'));
      await tester.pumpAndSettle();

      expect(
        api.calls.where((call) => call.startsWith('update 1')),
        isNotEmpty,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('holding and moving a game drags it to another group', (
      tester,
    ) async {
      final api = await openOnPhone(tester);
      final target = find.byKey(const Key('group-status:Completed'));
      await tester.ensureVisible(tile(1));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(tile(1)));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(find.byKey(const Key('drag-preview')), findsOneWidget);
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(api.calls, contains('update 1 {status: Completed}'));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a quick swipe over a game still scrolls', (tester) async {
      await openOnPhone(tester);
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('page-library')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final before = scrollable.position.pixels;

      await tester.drag(tile(1), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(before));
      expect(find.byKey(const Key('drag-preview')), findsNothing);
    });

    testWidgets('pulling the library down loads the games again', (
      tester,
    ) async {
      final api = await openOnPhone(tester);
      final before = api.calls.where((c) => c.startsWith('entries')).length;

      await tester.fling(
        find.byKey(const Key('page-library')),
        const Offset(0, 500),
        1500,
      );
      await tester.pumpAndSettle();

      expect(
        api.calls.where((c) => c.startsWith('entries')).length,
        greaterThan(before),
      );
    });

    testWidgets('a failed reload keeps the games on the screen', (
      tester,
    ) async {
      final api = await openOnPhone(tester);
      api.onEntries = (spaceId) async => throw Exception('offline');

      await tester.fling(
        find.byKey(const Key('page-library')),
        const Offset(0, 500),
        1500,
      );
      await tester.pumpAndSettle();

      expect(tile(1), findsOneWidget);
    });

    testWidgets('pulling an empty library down loads the games again', (
      tester,
    ) async {
      final api = FakeBacklogApi(entries: const []);
      await pumpLibrary(
        tester,
        api,
        overrides: [isDesktopProvider.overrideWithValue(false)],
      );
      await resize(tester, phone);
      final before = api.calls.where((c) => c.startsWith('entries')).length;

      await tester.fling(
        find.byKey(const Key('library-empty-add')),
        const Offset(0, 500),
        1500,
      );
      await tester.pumpAndSettle();

      expect(
        api.calls.where((c) => c.startsWith('entries')).length,
        greaterThan(before),
      );
    });

    testWidgets('the top bar opens the command palette', (tester) async {
      await openOnPhone(tester);

      await tester.tap(find.byKey(const Key('mobile-palette')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('command-palette')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a long press does nothing on the desktop', (tester) async {
    await pumpLibrary(tester, FakeBacklogApi(entries: const [hades, celeste]));

    await tester.longPress(tile(1));
    await tester.pumpAndSettle();

    expect(submenu('Move to status'), findsNothing);
  });
}
