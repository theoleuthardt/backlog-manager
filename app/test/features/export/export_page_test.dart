import 'dart:convert';

import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/platform/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../settings/backups_tab_test.dart' show FakeFileSaver;
import '../settings/settings_page_test.dart' show openSettings;

BacklogEntry entry(int id, String title, String status) =>
    BacklogEntry(id: id, title: title, status: status, review: 'Great');

Future<(FakeFileSaver, FakeBacklogApi)> open(
  WidgetTester tester, {
  List<BacklogEntry>? entries,
}) async {
  final saver = FakeFileSaver();
  final backlog = FakeBacklogApi(
    entries:
        entries ??
        [
          entry(1, 'Hades', 'Completed'),
          entry(2, 'Celeste', 'Playing'),
          entry(3, 'Portal', 'Completed'),
        ],
  );
  await openSettings(
    tester,
    location: '/export',
    overrides: [
      fileSaverProvider.overrideWithValue(saver),
      backlogApiProvider.overrideWithValue(backlog),
    ],
  );
  return (saver, backlog);
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('export-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the title, the description and the entry count', (
    tester,
  ) async {
    await open(tester);

    expect(find.byKey(const Key('page-export')), findsOneWidget);
    expect(find.text('Export backlog'), findsOneWidget);
    expect(find.textContaining('CSV file you can open'), findsOneWidget);
    expect(find.text('3 games'), findsOneWidget);
    expect(find.text('All statuses'), findsOneWidget);
  });

  testWidgets('saves every entry as a dated CSV file', (tester) async {
    final (saver, _) = await open(tester);

    await save(tester);

    expect(saver.saved, hasLength(1));
    final (name, bytes) = saver.saved.single;
    expect(name, matches(RegExp(r'^backlog-export-\d{4}-\d{2}-\d{2}\.csv$')));
    final lines = const LineSplitter().convert(utf8.decode(bytes));
    expect(lines, hasLength(3));
    expect(lines.first, contains('"Hades"'));
    expect(find.text('Successfully exported 3 entries!'), findsOneWidget);
    await dismissToast(tester);
  });

  testWidgets('leaves out the reviews when they are switched off', (
    tester,
  ) async {
    final (saver, _) = await open(tester);

    await tester.tap(find.byKey(const Key('export-reviews')));
    await tester.pump();
    await save(tester);

    expect(utf8.decode(saver.saved.single.$2), isNot(contains('Great')));
    await dismissToast(tester);
  });

  testWidgets('includes the reviews by default', (tester) async {
    final (saver, _) = await open(tester);

    await save(tester);

    expect(utf8.decode(saver.saved.single.$2), contains('Great'));
    await dismissToast(tester);
  });

  testWidgets('exports only the chosen status', (tester) async {
    final (saver, _) = await open(tester);

    await tester.tap(find.byKey(const Key('export-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playing').last);
    await tester.pumpAndSettle();

    expect(find.text('1 game'), findsOneWidget);
    await save(tester);

    final csv = utf8.decode(saver.saved.single.$2);
    expect(csv, contains('Celeste'));
    expect(csv, isNot(contains('Hades')));
    expect(find.text('Successfully exported 1 entry!'), findsOneWidget);
    await dismissToast(tester);
  });

  testWidgets('says so when there is nothing to export', (tester) async {
    final (saver, _) = await open(tester, entries: const []);

    await save(tester);

    expect(saver.saved, isEmpty);
    expect(find.text('No backlog entries found to export'), findsOneWidget);
    await dismissToast(tester);
  });

  testWidgets('stays quiet when the save dialog is cancelled', (tester) async {
    final (saver, _) = await open(tester);
    saver.cancel = true;

    await save(tester);

    expect(saver.saved, isEmpty);
    expect(find.textContaining('Successfully exported'), findsNothing);
  });

  testWidgets('cancel goes back to the library', (tester) async {
    await open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page-export')), findsNothing);
  });
}

Future<void> dismissToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 6));
