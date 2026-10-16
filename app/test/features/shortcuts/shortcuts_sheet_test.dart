import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show backlog, pumpLibrary;

void main() {
  testWidgets('the sidebar entry lists every shortcut of the app', (
    tester,
  ) async {
    await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

    await tester.tap(find.byKey(const Key('nav-shortcuts')));
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('shortcuts-list'));
    expect(list, findsOneWidget);
    for (final text in [
      'Open the command palette',
      'Ctrl+K',
      'Add Game',
      'Ctrl+N',
      'Focus the search field',
      'Ctrl+S',
      'Esc',
    ]) {
      expect(
        find.descendant(of: list, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
  });
}
