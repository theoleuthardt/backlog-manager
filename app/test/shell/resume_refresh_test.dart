import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fakes.dart';
import '../features/inspector/entry_inspector_test.dart' show celeste, hades;
import '../features/library/library_page_test.dart' show pumpLibrary;

Future<void> leaveAndComeBack(WidgetTester tester) async {
  tester.binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('coming back to the app shows what another device changed', (
    tester,
  ) async {
    final api = FakeBacklogApi(entries: const [hades]);
    await pumpLibrary(tester, api);
    expect(find.text(celeste.title), findsNothing);

    api.stored[celeste.id] = celeste;
    await leaveAndComeBack(tester);

    expect(find.text(celeste.title), findsWidgets);
  });

  testWidgets('a quick return does not load everything again', (tester) async {
    final api = FakeBacklogApi(entries: const [hades]);
    await pumpLibrary(tester, api);
    await leaveAndComeBack(tester);

    api.stored[celeste.id] = celeste;
    await leaveAndComeBack(tester);

    expect(find.text(celeste.title), findsNothing);
  });
}
