import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/common/category_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../../design/widgets/harness.dart';

const story = Category(id: 1, name: 'Story', color: '#38bdf8');
const coop = Category(id: 2, name: 'Co-op nights', color: '#4ade80');

Future<FakeBacklogApi> pumpManager(
  WidgetTester tester, {
  List<Category> categories = const [story, coop],
  int? spaceId,
}) async {
  final api = FakeBacklogApi()..categoryList = categories;
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [backlogApiProvider.overrideWithValue(api)],
      child: themed(
        'shelfOled',
        Builder(
          builder: (context) => TextButton(
            key: const Key('open-manager'),
            onPressed: () => showCategoryManager(context, spaceId: spaceId),
            child: const Text('Manage'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-manager')));
  await tester.pumpAndSettle();
  return api;
}

Future<void> rename(WidgetTester tester, int id, String name) async {
  await tester.enterText(find.byKey(Key('category-name-$id')), name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists one row per category', (tester) async {
    await pumpManager(tester);

    expect(find.text('Manage categories'), findsOneWidget);
    expect(find.byKey(const Key('category-row-1')), findsOneWidget);
    expect(find.byKey(const Key('category-row-2')), findsOneWidget);
  });

  testWidgets('says so when there are no categories', (tester) async {
    await pumpManager(tester, categories: const []);

    expect(
      find.text("No categories yet - create one from a game's Overview tab."),
      findsOneWidget,
    );
  });

  group('renaming', () {
    testWidgets('saves a new name on Enter', (tester) async {
      final api = await pumpManager(tester);

      await rename(tester, 1, ' Plot ');

      expect(api.calls, contains('update-category 1 Plot - personal'));
    });

    testWidgets('does not save an unchanged name', (tester) async {
      final api = await pumpManager(tester);

      await rename(tester, 1, 'Story');

      expect(api.calls.where((c) => c.startsWith('update-category')), isEmpty);
    });

    testWidgets('shows the duplicate message and resets the row', (
      tester,
    ) async {
      final api = await pumpManager(tester);

      await tester.enterText(
        find.byKey(const Key('category-name-1')),
        'co-op nights',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('You already have a category with that name'),
        findsOneWidget,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(api.calls.where((c) => c.startsWith('update-category')), isEmpty);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('category-name-1')))
            .controller!
            .text,
        'Story',
      );
    });

    testWidgets('resets the row and tells the user when the save fails', (
      tester,
    ) async {
      final api = await pumpManager(tester);
      api.onUpdateCategory = (id) async =>
          throw const ApiException('Server unavailable');

      await rename(tester, 1, 'Plot');

      expect(find.textContaining('Server unavailable'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('category-name-1')))
            .controller!
            .text,
        'Story',
      );
      await tester.pump(const Duration(seconds: 6));
    });
  });

  testWidgets('recolours a category', (tester) async {
    final api = await pumpManager(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('category-row-1')),
        matching: find.byKey(const Key('color-picker')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('color-option-#f87171')));
    await tester.pumpAndSettle();

    expect(api.calls, contains('update-category 1 - #f87171 personal'));
  });

  group('deleting', () {
    testWidgets('asks first and then removes the category', (tester) async {
      final api = await pumpManager(tester);

      await tester.tap(find.byKey(const Key('category-delete-1')));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Story"?'), findsOneWidget);
      expect(
        find.text(
          'The category is removed from every game that uses it. The games '
          'themselves stay in your backlog.',
        ),
        findsOneWidget,
      );
      expect(api.calls.where((c) => c.startsWith('delete-category')), isEmpty);

      await tester.tap(find.byKey(const Key('category-delete-confirm')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('delete-category 1 personal'));
      expect(find.byKey(const Key('category-row-1')), findsNothing);
      expect(find.text('Category "Story" deleted'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('keeps the category when the user cancels', (tester) async {
      final api = await pumpManager(tester);

      await tester.tap(find.byKey(const Key('category-delete-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(api.calls.where((c) => c.startsWith('delete-category')), isEmpty);
      expect(find.byKey(const Key('category-row-1')), findsOneWidget);
    });
  });

  testWidgets('works on the categories of a shared space', (tester) async {
    final api = await pumpManager(tester, spaceId: 4);

    await rename(tester, 1, 'Plot');

    expect(api.calls, contains('update-category 1 Plot - 4'));
  });
}
