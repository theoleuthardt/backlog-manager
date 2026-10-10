import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/common/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../../design/widgets/harness.dart';

const portal = BacklogEntry(id: 1, title: 'Portal 2');
const story = Category(id: 1, name: 'story', color: '#38bdf8');
const coop = Category(id: 2, name: 'Co-op nights', color: '#4ade80');

Future<FakeBacklogApi> pumpPicker(
  WidgetTester tester, {
  List<Category> categories = const [story, coop],
  List<Category> assigned = const [],
  int? spaceId,
}) async {
  final api = FakeBacklogApi(entries: [portal])
    ..categoryList = categories
    ..entriesByCategory = {
      for (final category in assigned) category.id: [portal],
    };
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [backlogApiProvider.overrideWithValue(api)],
      child: themed(
        'shelfOled',
        CategoryPicker(entryId: 1, spaceId: spaceId),
        width: 560,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> openList(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('category-add')));
  await tester.pumpAndSettle();
}

Future<void> typeName(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('new-category-name')), name);
  await tester.pumpAndSettle();
}

void main() {
  group('the chips', () {
    testWidgets('show the categories of the game with a colour dot', (
      tester,
    ) async {
      await pumpPicker(tester, assigned: const [coop]);

      expect(
        find.byKey(const Key('category-chip-Co-op nights')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('category-chip-story')), findsNothing);
    });

    testWidgets('remove a category from the game with their x', (tester) async {
      final api = await pumpPicker(tester, assigned: const [coop]);

      await tester.tap(find.byKey(const Key('category-remove-Co-op nights')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('remove-category 1 2 personal'));
      expect(find.byKey(const Key('category-chip-Co-op nights')), findsNothing);
    });
  });

  group('the list', () {
    testWidgets(
      'is alphabetical, ignoring case, with checks on assigned ones',
      (tester) async {
        await pumpPicker(tester, assigned: const [story]);
        await openList(tester);

        final coopTop = tester.getTopLeft(
          find.byKey(const Key('category-option-Co-op nights')),
        );
        final storyTop = tester.getTopLeft(
          find.byKey(const Key('category-option-story')),
        );
        expect(coopTop.dy, lessThan(storyTop.dy));
        expect(
          find.descendant(
            of: find.byKey(const Key('category-option-story')),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('category-option-Co-op nights')),
            matching: find.byIcon(Icons.check),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('toggles a category of the game', (tester) async {
      final api = await pumpPicker(tester);
      await openList(tester);

      await tester.tap(find.byKey(const Key('category-option-story')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('add-category 1 1 personal'));
      expect(find.byKey(const Key('category-chip-story')), findsOneWidget);

      await tester.tap(find.byKey(const Key('category-option-story')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('remove-category 1 1 personal'));
      expect(find.byKey(const Key('category-chip-story')), findsNothing);
    });

    testWidgets('tells the user when toggling fails', (tester) async {
      final api = await pumpPicker(tester);
      api.onSetEntryCategory = (entryId, categoryId, assigned) async =>
          throw const ApiException('Server unavailable');
      await openList(tester);

      await tester.tap(find.byKey(const Key('category-option-story')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Server unavailable'), findsOneWidget);
      expect(find.byKey(const Key('category-chip-story')), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('a new category', () {
    testWidgets(
      'is created with the next palette colour and added to the game',
      (tester) async {
        final api = await pumpPicker(tester);
        await openList(tester);

        await typeName(tester, '  Speedruns ');
        await tester.tap(find.byKey(const Key('category-create')));
        await tester.pumpAndSettle();

        expect(
          api.calls,
          contains('create-category Speedruns #fbbf24 personal'),
        );
        expect(api.calls, contains('add-category 1 100 personal'));
        expect(
          find.byKey(const Key('category-chip-Speedruns')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('new-category-name')))
              .controller!
              .text,
          '',
        );
      },
    );

    testWidgets('is created with Enter', (tester) async {
      final api = await pumpPicker(tester);
      await openList(tester);

      await typeName(tester, 'Speedruns');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        api.calls.where((c) => c.startsWith('create-category')),
        hasLength(1),
      );
    });

    testWidgets('uses the colour that was picked', (tester) async {
      final api = await pumpPicker(tester);
      await openList(tester);

      await tester.tap(find.byKey(const Key('color-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('color-option-#f87171')));
      await tester.pumpAndSettle();
      await typeName(tester, 'Speedruns');
      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('create-category Speedruns #f87171 personal'));
    });

    testWidgets('rejects a duplicate name, ignoring case', (tester) async {
      final api = await pumpPicker(tester);
      await openList(tester);

      await typeName(tester, 'CO-OP NIGHTS');
      expect(
        find.text('You already have a category with that name'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();

      expect(api.calls.where((c) => c.startsWith('create-category')), isEmpty);
    });

    testWidgets('rejects a name over 100 characters', (tester) async {
      await pumpPicker(tester);
      await openList(tester);

      await tester.enterText(
        find.byKey(const Key('new-category-name')),
        'a' * 101,
      );
      await tester.pumpAndSettle();

      expect(find.text('Max 100 characters'), findsOneWidget);
    });

    testWidgets('tells the user when the category was made but not added', (
      tester,
    ) async {
      final api = await pumpPicker(tester);
      api.onSetEntryCategory = (entryId, categoryId, assigned) async =>
          throw const ApiException('Server unavailable');
      await openList(tester);

      await typeName(tester, 'Speedruns');
      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Category "Speedruns" was created but could not be added to this game',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('does nothing for an empty name', (tester) async {
      final api = await pumpPicker(tester);
      await openList(tester);

      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();

      expect(api.calls.where((c) => c.startsWith('create-category')), isEmpty);
    });
  });

  group('in a shared space', () {
    testWidgets('uses the categories of that space', (tester) async {
      final api = await pumpPicker(tester, spaceId: 4);
      await openList(tester);

      await tester.tap(find.byKey(const Key('category-option-story')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('categories 4'));
      expect(api.calls, contains('add-category 1 1 4'));
    });
  });
}
