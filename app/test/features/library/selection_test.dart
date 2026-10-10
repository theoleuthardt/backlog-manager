import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';

class SignedIn extends SessionNotifier {
  @override
  SessionState build() => const SessionSignedIn(
    SessionUser(name: 'Theo', email: 'theo@example.com', setupCompleted: true),
  );
}

BacklogEntry game(int id, String title, {String status = 'Not Started'}) {
  return BacklogEntry(id: id, title: title, status: status);
}

FakeBacklogApi backlog({bool withCategories = true}) {
  final api = FakeBacklogApi(
    entries: [
      game(1, 'Elden Ring', status: 'In Progress'),
      game(2, 'Celeste'),
      game(3, 'Portal 2'),
      game(4, 'Disco Elysium', status: 'On Hold'),
    ],
  );
  if (withCategories) {
    api
      ..categoryList = const [Category(id: 1, name: 'Story', color: '#38bdf8')]
      ..entriesByCategory = {
        1: [game(3, 'Portal 2')],
      };
  }
  return api;
}

Future<ProviderContainer> pumpLibrary(
  WidgetTester tester,
  FakeBacklogApi api,
) async {
  tester.view.physicalSize = const Size(1440, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        sessionProvider.overrideWith(SignedIn.new),
        backlogApiProvider.overrideWithValue(api),
      ],
      child: const BacklogManagerApp(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(routerProvider).go(AppRoutes.library);
  await tester.pumpAndSettle();
  return container;
}

Finder menuItem(String label) => find.descendant(
  of: find.byType(MenuItemButton),
  matching: find.text(label),
);

Finder cover(String title) =>
    find.descendant(of: find.byType(ShelfCover), matching: find.text(title));

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> startSelecting(WidgetTester tester) =>
    tapKey(tester, 'select-toggle');

Future<void> tapCover(WidgetTester tester, String title) async {
  await tester.tap(cover(title));
  await tester.pumpAndSettle();
}

Future<void> rightClick(WidgetTester tester, String title) async {
  await tester.tap(cover(title), buttons: kSecondaryMouseButton);
  await tester.pumpAndSettle();
}

Finder inBar(Finder matching) => find.descendant(
  of: find.byKey(const Key('selection-bar')),
  matching: matching,
);

Finder inStatusBar(Finder matching) => find.descendant(
  of: find.byKey(const Key('status-bar')),
  matching: matching,
);

int selectedCount(WidgetTester tester) =>
    find.byKey(const Key('cover-ring')).evaluate().length;

Future<void> chooseFromBar(
  WidgetTester tester,
  String barKey,
  String item,
) async {
  await tapKey(tester, barKey);
  await tester.tap(menuItem(item));
  await tester.pumpAndSettle();
}

String? entryParameter(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .queryParameters['entry'];

void main() {
  group('selection mode', () {
    testWidgets('starts from the Select button with the contextual bar', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      expect(find.byKey(const Key('selection-bar')), findsNothing);

      await startSelecting(tester);

      expect(find.byKey(const Key('selection-bar')), findsOneWidget);
      expect(inBar(find.text('0 selected')), findsOneWidget);
      expect(inBar(find.text('Select all 4')), findsOneWidget);
      expect(find.byKey(const Key('cover-check')), findsNWidgets(4));
    });

    testWidgets('a click toggles a cover instead of opening it', (
      tester,
    ) async {
      final container = await pumpLibrary(tester, backlog());
      await startSelecting(tester);

      await tapCover(tester, 'Celeste');
      await tapCover(tester, 'Portal 2');
      expect(inBar(find.text('2 selected')), findsOneWidget);
      expect(selectedCount(tester), 2);

      await tapCover(tester, 'Celeste');
      expect(inBar(find.text('1 selected')), findsOneWidget);
      expect(entryParameter(container), isNull);
    });

    testWidgets('a click on a cover outside selection opens its details', (
      tester,
    ) async {
      final container = await pumpLibrary(tester, backlog());

      await tapCover(tester, 'Celeste');

      expect(entryParameter(container), '2');
    });

    testWidgets('select all takes the visible games, clear empties', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      await tester.enterText(find.byKey(const Key('search-field')), 'e');
      await tester.pumpAndSettle();
      await startSelecting(tester);

      expect(inBar(find.text('Select all 3')), findsOneWidget);
      await tapKey(tester, 'select-all');
      expect(inBar(find.text('3 selected')), findsOneWidget);
      expect(
        tester
            .widget<ShelfButton>(find.byKey(const Key('select-all')))
            .onPressed,
        isNull,
      );

      await tapKey(tester, 'selection-clear');
      expect(inBar(find.text('0 selected')), findsOneWidget);
    });

    testWidgets('Done leaves the mode and drops the selection', (tester) async {
      await pumpLibrary(tester, backlog());
      await startSelecting(tester);
      await tapCover(tester, 'Celeste');

      await tapKey(tester, 'selection-done');

      expect(find.byKey(const Key('selection-bar')), findsNothing);
      expect(find.byKey(const Key('cover-check')), findsNothing);
    });

    testWidgets('the status bar counts the selected games', (tester) async {
      await pumpLibrary(tester, backlog());
      await startSelecting(tester);

      await tapCover(tester, 'Celeste');
      await tapCover(tester, 'Portal 2');

      expect(inStatusBar(find.text('2 of 4 games selected')), findsOneWidget);
    });
  });

  group('bulk set status', () {
    testWidgets('moves every selected game and reports it', (tester) async {
      final api = backlog();
      await pumpLibrary(tester, api);
      await startSelecting(tester);
      await tapCover(tester, 'Celeste');
      await tapCover(tester, 'Portal 2');

      await chooseFromBar(tester, 'selection-set-status', 'Completed');

      expect(api.calls.where((c) => c.startsWith('update')).length, 2);
      expect(api.stored[2]!.status, 'Completed');
      expect(api.stored[3]!.status, 'Completed');
      expect(find.text('Moved 2 games to Completed'), findsOneWidget);
      expect(find.byKey(const Key('selection-bar')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('says how many failed', (tester) async {
      final api = backlog();
      api.onUpdate = (id, update) async {
        if (id == 3) throw const ApiException('nope');
      };
      await pumpLibrary(tester, api);
      await startSelecting(tester);
      await tapCover(tester, 'Celeste');
      await tapCover(tester, 'Portal 2');

      await chooseFromBar(tester, 'selection-set-status', 'Dropped');

      expect(find.text('Moved 1 to Dropped, 1 failed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('is disabled while nothing is selected', (tester) async {
      await pumpLibrary(tester, backlog());
      await startSelecting(tester);

      expect(
        tester
            .widget<ShelfButton>(find.byKey(const Key('selection-set-status')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ShelfButton>(find.byKey(const Key('selection-delete')))
            .onPressed,
        isNull,
      );
    });
  });

  group('bulk delete', () {
    testWidgets('asks first and then deletes the selection', (tester) async {
      final api = backlog();
      await pumpLibrary(tester, api);
      await startSelecting(tester);
      await tapCover(tester, 'Celeste');
      await tapCover(tester, 'Portal 2');

      await tapKey(tester, 'selection-delete');
      expect(find.text('Delete 2 games?'), findsOneWidget);
      expect(
        find.text(
          'This action cannot be undone. This will permanently delete these '
          'backlog entries from your collection.',
        ),
        findsOneWidget,
      );
      expect(api.calls.where((c) => c.startsWith('delete ')), isEmpty);

      await tapKey(tester, 'delete-confirm');

      expect(api.calls.where((c) => c.startsWith('delete ')).length, 2);
      expect(find.text('Deleted 2 games'), findsOneWidget);
      expect(cover('Celeste'), findsNothing);
      expect(inBar(find.text('0 selected')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('keeps everything when the user cancels', (tester) async {
      final api = backlog();
      await pumpLibrary(tester, api);
      await startSelecting(tester);
      await tapCover(tester, 'Celeste');

      await tapKey(tester, 'selection-delete');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(api.calls.where((c) => c.startsWith('delete ')), isEmpty);
      expect(cover('Celeste'), findsOneWidget);
      expect(inBar(find.text('1 selected')), findsOneWidget);
    });

    testWidgets('says how many failed', (tester) async {
      final api = backlog();
      api.onDelete = (id) async {
        if (id == 3) throw const ApiException('nope');
      };
      await pumpLibrary(tester, api);
      await startSelecting(tester);
      await tapCover(tester, 'Celeste');
      await tapCover(tester, 'Portal 2');

      await tapKey(tester, 'selection-delete');
      await tapKey(tester, 'delete-confirm');

      expect(find.text('Deleted 1, 1 failed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('bulk categories', () {
    testWidgets('adds a category to every selected game, then removes it', (
      tester,
    ) async {
      final api = backlog();
      await pumpLibrary(tester, api);
      await startSelecting(tester);
      await tapCover(tester, 'Celeste');
      await tapCover(tester, 'Elden Ring');

      await chooseFromBar(tester, 'selection-categories', 'Story');
      expect(api.calls, contains('add-category 1 1 personal'));
      expect(api.calls, contains('add-category 2 1 personal'));
      expect(find.text('Added 2 games to "Story"'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));

      await chooseFromBar(tester, 'selection-categories', 'Story');
      expect(api.calls, contains('remove-category 1 1 personal'));
      expect(api.calls, contains('remove-category 2 1 personal'));
      expect(find.text('Removed 2 games from "Story"'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('is disabled when there are no categories', (tester) async {
      await pumpLibrary(tester, backlog(withCategories: false));
      await startSelecting(tester);
      await tapCover(tester, 'Celeste');

      expect(
        tester
            .widget<ShelfButton>(find.byKey(const Key('selection-categories')))
            .onPressed,
        isNull,
      );
    });
  });

  group('the context menu', () {
    testWidgets('shows the title and the actions of a game', (tester) async {
      await pumpLibrary(tester, backlog());

      await rightClick(tester, 'Portal 2');

      expect(find.byKey(const Key('menu-label')), findsOneWidget);
      for (final label in [
        'Open details',
        'Select',
        'Move to status',
        'Categories',
        'Delete',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Enter'), findsOneWidget);
      expect(find.text('Backspace'), findsOneWidget);
    });

    testWidgets('open details opens the game', (tester) async {
      final container = await pumpLibrary(tester, backlog());

      await rightClick(tester, 'Portal 2');
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();

      expect(entryParameter(container), '3');
    });

    testWidgets('Select starts a selection with that game', (tester) async {
      await pumpLibrary(tester, backlog());

      await rightClick(tester, 'Portal 2');
      await tester.tap(menuItem('Select'));
      await tester.pumpAndSettle();

      expect(inBar(find.text('1 selected')), findsOneWidget);
      expect(selectedCount(tester), 1);
    });

    testWidgets('Move to status moves the game and offers Undo', (
      tester,
    ) async {
      final api = backlog();
      await pumpLibrary(tester, api);

      await rightClick(tester, 'Portal 2');
      await tester.tap(find.text('Move to status'));
      await tester.pumpAndSettle();
      await tester.tap(menuItem('Completed'));
      await tester.pumpAndSettle();

      expect(api.stored[3]!.status, 'Completed');
      expect(find.text('Moved "Portal 2" to Completed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(api.stored[3]!.status, 'Not Started');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the current status cannot be chosen again', (tester) async {
      final api = backlog();
      await pumpLibrary(tester, api);

      await rightClick(tester, 'Portal 2');
      await tester.tap(find.text('Move to status'));
      await tester.pumpAndSettle();
      await tester.tap(menuItem('Not Started'));
      await tester.pumpAndSettle();

      expect(api.calls.where((c) => c.startsWith('update')), isEmpty);
    });

    testWidgets('Categories toggles a category and stays open', (tester) async {
      final api = backlog();
      await pumpLibrary(tester, api);

      await rightClick(tester, 'Celeste');
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      await tester.tap(menuItem('Story'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('add-category 2 1 personal'));
      expect(find.text('Story'), findsWidgets);
    });

    testWidgets('Categories is disabled without categories', (tester) async {
      await pumpLibrary(tester, backlog(withCategories: false));

      await rightClick(tester, 'Celeste');

      final item = tester.widget<MenuItemButton>(
        find.ancestor(
          of: find.text('Categories'),
          matching: find.byType(MenuItemButton),
        ),
      );
      expect(item.onPressed, isNull);
    });

    testWidgets('Delete asks about that game and deletes it', (tester) async {
      final api = backlog();
      await pumpLibrary(tester, api);

      await rightClick(tester, 'Portal 2');
      await tester.tap(menuItem('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Portal 2"?'), findsOneWidget);
      expect(
        find.text(
          'This action cannot be undone. This will permanently delete this '
          'backlog entry from your collection.',
        ),
        findsOneWidget,
      );

      await tapKey(tester, 'delete-confirm');

      expect(api.calls, contains('delete 3'));
      expect(find.text('"Portal 2" deleted'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('the keyboard', () {
    Future<void> focusCover(WidgetTester tester, int id) async {
      Focus.of(tester.element(find.byKey(Key('library-tile-$id'))))
          .requestFocus();
      await tester.pumpAndSettle();
    }

    testWidgets('Enter opens a focused cover', (tester) async {
      final container = await pumpLibrary(tester, backlog());
      await focusCover(tester, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(entryParameter(container), '2');
    });

    testWidgets('Space toggles a focused cover while selecting', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      await startSelecting(tester);
      await focusCover(tester, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(inBar(find.text('1 selected')), findsOneWidget);
    });

    testWidgets('Backspace asks to delete the focused game', (tester) async {
      await pumpLibrary(tester, backlog());
      await focusCover(tester, 3);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(find.text('Delete "Portal 2"?'), findsOneWidget);
    });

    testWidgets('the arrow keys move the focus to the next cover', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      await focusCover(tester, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(
        Focus.of(tester.element(find.byKey(const Key('library-tile-3'))))
            .hasFocus,
        isTrue,
      );
    });
  });
}
