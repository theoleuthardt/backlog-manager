import 'dart:ui';

import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import 'library_page_test.dart' show backlog, pumpLibrary;

const rpg = Category(id: 1, name: 'RPG', color: '#ff0000');
const indie = Category(id: 2, name: 'Indie', color: '#00ff00');
const cozy = Category(id: 3, name: 'Cozy', color: '#0000ff');

Future<void> dragTo(
  WidgetTester tester,
  Key from,
  Finder to, {
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(from)),
    kind: kind,
  );
  await gesture.moveBy(const Offset(0, 24));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('the status sort', () {
    testWidgets('moves a game to the group it is dropped on, with an undo', (
      tester,
    ) async {
      final api = FakeBacklogApi(entries: backlog);
      await pumpLibrary(tester, api);

      await dragTo(
        tester,
        const ValueKey('tile-2'),
        find.byKey(const Key('group-status:Completed')),
      );

      expect(api.calls, contains('update 2 {status: Completed}'));
      expect(find.text('Moved "Celeste" to Completed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('update 2 {status: Not Started}'));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('does nothing when dropped on the group it is in', (
      tester,
    ) async {
      final api = FakeBacklogApi(entries: backlog);
      await pumpLibrary(tester, api);

      await dragTo(
        tester,
        const ValueKey('tile-2'),
        find.byKey(const Key('group-status:Not Started')),
      );

      expect(api.calls.where((call) => call.startsWith('update')), isEmpty);
      expect(find.textContaining('Moved'), findsNothing);
    });

    testWidgets('does nothing when dropped outside the groups', (tester) async {
      final api = FakeBacklogApi(entries: backlog);
      await pumpLibrary(tester, api);

      await dragTo(
        tester,
        const ValueKey('tile-2'),
        find.byKey(const Key('select-toggle')),
      );

      expect(api.calls.where((call) => call.startsWith('update')), isEmpty);
    });

    testWidgets('highlights the group under the pointer while dragging', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('tile-2'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('group-status:Completed'))),
      );
      await tester.pump();

      expect(find.byKey(const Key('drop-target')), findsOneWidget);
      expect(find.byKey(const Key('drag-preview')), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('drop-target')), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('keeps a click a click', (tester) async {
      final api = FakeBacklogApi(entries: backlog);
      await pumpLibrary(tester, api);

      await tester.tap(find.byKey(const ValueKey('tile-2')));
      await tester.pumpAndSettle();

      expect(api.calls.where((call) => call.startsWith('update')), isEmpty);
    });

    testWidgets('shows a hint in an empty status group while dragging', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));
      expect(find.byKey(const Key('drop-hint')), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('tile-2'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();

      expect(find.byKey(const Key('drop-hint')), findsWidgets);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('the category sort', () {
    FakeBacklogApi categorized() => FakeBacklogApi(entries: backlog)
      ..categoryList = [rpg, indie, cozy]
      ..entriesByCategory = {
        1: [backlog[0]],
        2: [backlog[1]],
      };

    testWidgets('adds the target category and removes the first one', (
      tester,
    ) async {
      final api = categorized();
      await pumpLibrary(tester, api, defaultSort: 'category');

      await dragTo(
        tester,
        const ValueKey('tile-1'),
        find.byKey(const Key('group-category:Indie')),
      );

      expect(api.calls, contains('add-category 1 2 personal'));
      expect(api.calls, contains('remove-category 1 1 personal'));
      expect(find.text('Moved "Elden Ring" to Indie'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('drops on an empty category', (tester) async {
      final api = categorized();
      await pumpLibrary(tester, api, defaultSort: 'category');

      await dragTo(
        tester,
        const ValueKey('tile-1'),
        find.byKey(const Key('group-category:Cozy')),
      );

      expect(api.calls, contains('add-category 1 3 personal'));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('says so when the category was added but not removed', (
      tester,
    ) async {
      final api = categorized()
        ..onSetEntryCategory = (entryId, categoryId, assigned) async {
          if (!assigned) throw Exception('offline');
        };
      await pumpLibrary(tester, api, defaultSort: 'category');

      await dragTo(
        tester,
        const ValueKey('tile-1'),
        find.byKey(const Key('group-category:Indie')),
      );

      expect(
        find.text('Added to Indie but could not remove RPG'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('does nothing on the category the game is already in', (
      tester,
    ) async {
      final api = categorized();
      await pumpLibrary(tester, api, defaultSort: 'category');

      await dragTo(
        tester,
        const ValueKey('tile-1'),
        find.byKey(const Key('group-category:RPG')),
      );

      expect(api.calls.where((call) => call.contains('-category 1')), isEmpty);
    });

    testWidgets('does not take a drop on the games without a category', (
      tester,
    ) async {
      final api = categorized();
      await pumpLibrary(tester, api, defaultSort: 'category');

      await dragTo(
        tester,
        const ValueKey('tile-1'),
        find.byKey(const Key('group-category:Uncategorized')),
      );

      expect(api.calls.where((call) => call.contains('-category 1')), isEmpty);
    });
  });

  group('where dragging is off', () {
    testWidgets('in the other sort options', (tester) async {
      final api = FakeBacklogApi(entries: backlog);
      await pumpLibrary(tester, api, defaultSort: 'genre');

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('tile-2'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();

      expect(find.byKey(const Key('drag-preview')), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('while selecting', (tester) async {
      final api = FakeBacklogApi(entries: backlog);
      await pumpLibrary(tester, api);
      await tester.tap(find.byKey(const Key('select-toggle')));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('tile-2'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();

      expect(find.byKey(const Key('drag-preview')), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('scrolls while the pointer is near the bottom edge', (
    tester,
  ) async {
    await pumpLibrary(tester, FakeBacklogApi(entries: backlog), height: 700);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tile-2'))),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveTo(Offset(700, tester.view.physicalSize.height - 40));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(scrollable.position.pixels, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a finger needs a hold before the drag starts', (tester) async {
    final api = FakeBacklogApi(entries: backlog);
    await pumpLibrary(tester, api);

    final quick = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tile-2'))),
    );
    await quick.moveBy(const Offset(0, 24));
    await tester.pump();
    expect(find.byKey(const Key('drag-preview')), findsNothing);
    await quick.up();
    await tester.pumpAndSettle();

    final held = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tile-2'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await held.moveBy(const Offset(0, 24));
    await tester.pump();
    expect(find.byKey(const Key('drag-preview')), findsOneWidget);
    await held.up();
    await tester.pumpAndSettle();
  });
}
