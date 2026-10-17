import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  status: 'Not Started',
  owned: true,
  interest: 5,
);

Finder get title => find.byKey(const Key('inspector-title'));
Finder get input => find.byKey(const Key('inspector-title-input'));

String shownTitle(WidgetTester tester) => tester.widget<Text>(title).data ?? '';

Future<dynamic> open(WidgetTester tester) =>
    openInspector(tester, entries: [hades, celeste]);

Future<void> edit(WidgetTester tester) async {
  await tester.tap(title);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Overview tab has no separate title field any more', (
    tester,
  ) async {
    await open(tester);

    expect(find.byKey(const Key('inspector-title-field')), findsNothing);
  });

  testWidgets('shows the title as text with a pencil next to it', (
    tester,
  ) async {
    await open(tester);

    expect(shownTitle(tester), 'Hades');
    expect(input, findsNothing);
    expect(find.byKey(const Key('inspector-title-edit')), findsOneWidget);
  });

  testWidgets('a click on the title turns it into a focused text field', (
    tester,
  ) async {
    await open(tester);

    await edit(tester);

    expect(input, findsOneWidget);
    final field = tester.widget<TextField>(input);
    expect(field.controller!.text, 'Hades');
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('the pencil does the same', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('inspector-title-edit')));
    await tester.pumpAndSettle();

    expect(input, findsOneWidget);
  });

  testWidgets('Enter saves the new title and shows it again as text', (
    tester,
  ) async {
    final app = await open(tester);
    await edit(tester);

    await tester.enterText(input, 'Hades (Demo)');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(input, findsNothing);
    expect(shownTitle(tester), 'Hades (Demo)');
    expect(app.api.calls, contains('update 1 {title: Hades (Demo)}'));
  });

  testWidgets('shows the new title at once, before the save is done', (
    tester,
  ) async {
    await open(tester);
    await edit(tester);

    await tester.enterText(input, 'Hades (Demo)');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(shownTitle(tester), 'Hades (Demo)');
    await afterAutosave(tester);
  });

  testWidgets('losing the focus keeps the edit and saves it', (tester) async {
    final app = await open(tester);
    await edit(tester);
    await tester.enterText(input, 'Hades II');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(input, findsNothing);
    expect(shownTitle(tester), 'Hades II');
    expect(app.api.calls, contains('update 1 {title: Hades II}'));
  });

  testWidgets('Esc discards the edit and leaves the details open', (
    tester,
  ) async {
    final app = await open(tester);
    await edit(tester);
    await tester.enterText(input, 'Something else');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(input, findsNothing);
    expect(shownTitle(tester), 'Hades');
    expect(app.api.calls.where((String c) => c.startsWith('update')), isEmpty);
    expect(find.byKey(const Key('entry-inspector')), findsOneWidget);
  });

  testWidgets('a blank title is never saved: the stored one comes back', (
    tester,
  ) async {
    final app = await open(tester);
    await edit(tester);

    await tester.enterText(input, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(shownTitle(tester), 'Hades');
    expect(app.api.calls.where((String c) => c.startsWith('update')), isEmpty);
  });

  testWidgets('a title that was not changed is not saved', (tester) async {
    final app = await open(tester);
    await edit(tester);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await afterAutosave(tester);

    expect(app.api.calls.where((String c) => c.startsWith('update')), isEmpty);
  });

  testWidgets('says why while the title is blank', (tester) async {
    await open(tester);
    await edit(tester);

    await tester.enterText(input, '');
    await tester.pump();

    expect(find.text('A game needs a title'), findsOneWidget);
  });
}
