import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'entry_inspector_test.dart' show afterAutosave, openInspector;

const hades = BacklogEntry(
  id: 1,
  title: 'Hades',
  platform: ['PC'],
  status: 'In Progress',
  owned: true,
  interest: 6,
);
const celeste = BacklogEntry(
  id: 2,
  title: 'Celeste',
  platform: ['PC', 'Switch'],
  status: 'Not Started',
  owned: true,
  interest: 5,
);

Finder get manage => find.byKey(const Key('inspector-platform-manage'));
Finder choice(String name) => find.byKey(Key('platform-choice-$name'));

Future<dynamic> open(WidgetTester tester) async {
  final app = await openInspector(tester, entries: [hades, celeste]);
  await tester.ensureVisible(manage);
  await tester.tap(manage);
  await tester.pumpAndSettle();
  return app;
}

String platformText(WidgetTester tester) {
  final field = find.descendant(
    of: find.byKey(const Key('inspector-platform')),
    matching: find.byType(TextField),
  );
  return tester.widget<TextField>(field).controller!.text;
}

void main() {
  testWidgets('a Manage button next to the Platform field opens the sheet', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Manage Platforms'), findsOneWidget);
  });

  testWidgets('offers the platforms of the backlog and the common ones', (
    tester,
  ) async {
    await open(tester);

    expect(choice('PC'), findsOneWidget);
    expect(choice('Switch'), findsOneWidget);
    expect(choice('PS5'), findsOneWidget);
  });

  testWidgets('shows what the game has as selected', (tester) async {
    await open(tester);

    expect(find.byKey(const Key('platform-selected-PC')), findsOneWidget);
    expect(find.byKey(const Key('platform-selected-Switch')), findsNothing);
  });

  testWidgets('adding a platform saves the game with it', (tester) async {
    final app = await open(tester);

    await tester.tap(choice('Switch'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('platforms-done')));
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(platformText(tester), 'PC, Switch');
    expect(app.api.calls, contains('update 1 {platform: [PC, Switch]}'));
  });

  testWidgets('removing a platform saves the game without it', (tester) async {
    final app = await open(tester);

    await tester.tap(choice('PC'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('platforms-done')));
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(platformText(tester), '');
    expect(app.api.calls, contains('update 1 {platform: []}'));
  });

  testWidgets('adds a platform of its own', (tester) async {
    final app = await open(tester);

    await tester.enterText(find.byKey(const Key('platform-new')), 'Amiga');
    await tester.tap(find.byKey(const Key('platform-add')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('platforms-done')));
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(platformText(tester), 'PC, Amiga');
    expect(app.api.calls, contains('update 1 {platform: [PC, Amiga]}'));
  });

  testWidgets('submitting the new name with Enter adds it', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('platform-new')), 'Amiga');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byKey(const Key('platform-selected-Amiga')), findsOneWidget);
  });

  testWidgets('Cancel leaves the game as it was', (tester) async {
    final app = await open(tester);

    await tester.tap(choice('Switch'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(platformText(tester), 'PC');
    expect(app.api.calls.where((String c) => c.startsWith('update')), isEmpty);
  });

  testWidgets('Done keeps a platform that arrived while the sheet was open', (
    tester,
  ) async {
    final app = await open(tester);
    await app.container
        .read(entriesProvider(null).notifier)
        .updateEntry(1, const EntryUpdate(platform: ['PC', 'Mac']));
    await tester.pumpAndSettle();

    await tester.tap(choice('Switch'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('platforms-done')));
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(platformText(tester), 'PC, Mac, Switch');
    expect(app.api.calls, contains('update 1 {platform: [PC, Mac, Switch]}'));
  });

  testWidgets('Done without a change does not write the old platforms back', (
    tester,
  ) async {
    final app = await open(tester);
    await app.container
        .read(entriesProvider(null).notifier)
        .updateEntry(1, const EntryUpdate(platform: ['PC', 'Mac']));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('platforms-done')));
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(platformText(tester), 'PC, Mac');
    expect(app.api.calls.where((String c) => c.startsWith('update')), [
      'update 1 {platform: [PC, Mac]}',
    ]);
  });

  testWidgets('the text field still works for a quick edit', (tester) async {
    final app = await openInspector(tester, entries: [hades, celeste]);
    final field = find.descendant(
      of: find.byKey(const Key('inspector-platform')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);

    await tester.enterText(field, 'PC, Mac');
    await tester.pump();
    await afterAutosave(tester);

    expect(app.api.calls, contains('update 1 {platform: [PC, Mac]}'));
  });

  testWidgets('golden: manage platforms', tags: 'golden', (tester) async {
    await open(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/manage_platforms.png'),
    );
  });
}
