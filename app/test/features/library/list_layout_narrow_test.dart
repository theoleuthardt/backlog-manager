import 'package:backlog_manager/features/library/library_view.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_font.dart';
import 'filter_bar_test.dart' show backlog, pumpLibrary;

void main() {
  setUpAll(loadAppFont);

  Future<void> openNarrowList(WidgetTester tester) async {
    final container = await pumpLibrary(tester, backlog());
    container.read(libraryViewProvider.notifier).setLayout(LibraryLayout.list);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1000, 2400);
    container.read(routerProvider).go('/library?entry=1');
    await tester.pumpAndSettle();
  }

  testWidgets('the list fits the smallest window with the details open', (
    tester,
  ) async {
    await openNarrowList(tester);

    expect(tester.takeException(), isNull);
    final rows = find.byWidgetPredicate(
      (w) => w.key.toString().contains('library-row-'),
    );
    expect(rows, findsWidgets);
    final pane = tester.getRect(find.byKey(const Key('page-library')));
    for (final row in rows.evaluate()) {
      final rect = tester.getRect(find.byWidget(row.widget));
      expect(rect.right, lessThanOrEqualTo(pane.right));
    }
  });

  testWidgets('a narrow row leaves out the genre and keeps title and status', (
    tester,
  ) async {
    await openNarrowList(tester);

    final row = find.byKey(const Key('library-row-1'));
    expect(
      find.descendant(of: row, matching: find.text('Elden Ring')),
      findsOne,
    );
    expect(
      find.descendant(of: row, matching: find.text('In Progress')),
      findsOne,
    );
    expect(find.descendant(of: row, matching: find.text('RPG')), findsNothing);
  });

  testWidgets('a wide row still shows the genre', (tester) async {
    final container = await pumpLibrary(tester, backlog());
    container.read(libraryViewProvider.notifier).setLayout(LibraryLayout.list);
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('library-row-1'));
    expect(find.descendant(of: row, matching: find.text('RPG')), findsOne);
  });
}
