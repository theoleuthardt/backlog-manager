import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show pumpLibrary;

BacklogEntry entry(
  int id,
  String title, {
  String status = 'Playing',
  List<String> platform = const ['PC'],
  int? steamAppId,
}) => BacklogEntry(
  id: id,
  title: title,
  status: status,
  platform: platform,
  steamAppId: steamAppId,
);

Future<FakeBacklogApi> open(
  WidgetTester tester,
  List<BacklogEntry> entries,
) async {
  final api = FakeBacklogApi(entries: entries);
  await pumpLibrary(tester, api, height: 1100);
  await tester.tap(find.byKey(const Key('duplicates-button')));
  await tester.pumpAndSettle();
  return api;
}

Future<void> dismissToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 6));

void main() {
  testWidgets('opens from the toolbar next to the IGDB sync', (tester) async {
    await open(tester, [entry(1, 'Hades'), entry(2, 'Hades')]);

    expect(find.text('Duplicate games'), findsOneWidget);
    expect(find.byKey(const Key('igdb-sync-button')), findsOneWidget);
  });

  testWidgets('says so when there are no duplicates', (tester) async {
    await open(tester, [entry(1, 'Hades'), entry(2, 'Celeste')]);

    expect(find.text('No duplicates found'), findsOneWidget);
  });

  testWidgets('lists a group with its reason and both entries', (tester) async {
    await open(tester, [
      entry(1, 'Hades'),
      entry(2, 'hades'),
      entry(3, 'Celeste'),
    ]);

    expect(
      find.text('1 game is in your backlog more than once (2 entries)'),
      findsOneWidget,
    );
    expect(find.text('Same title'), findsOneWidget);
    expect(find.byKey(const Key('duplicate-entry-1')), findsOneWidget);
    expect(find.byKey(const Key('duplicate-entry-2')), findsOneWidget);
    expect(find.byKey(const Key('duplicate-entry-3')), findsNothing);
    expect(find.text('Hades (oldest)'), findsOneWidget);
  });

  testWidgets('finds duplicates by Steam App ID', (tester) async {
    await open(tester, [
      entry(1, 'Portal 2', steamAppId: 620),
      entry(2, 'Portal Two', steamAppId: 620),
    ]);

    expect(find.text('Same Steam App ID'), findsOneWidget);
  });

  testWidgets('shows what the other entries differ in', (tester) async {
    await open(tester, [
      entry(1, 'Hades', status: 'Completed'),
      entry(2, 'Hades', status: 'Playing', platform: const ['Switch']),
    ]);

    expect(find.byKey(const Key('diff-status-old')), findsOneWidget);
    expect(find.byKey(const Key('diff-status-new')), findsOneWidget);
    expect(find.byKey(const Key('diff-platform-new')), findsOneWidget);
  });

  testWidgets('says when an entry is the same as the oldest', (tester) async {
    await open(tester, [entry(1, 'Hades'), entry(2, 'Hades')]);

    expect(
      find.text('No differences from the existing entry.'),
      findsOneWidget,
    );
  });

  testWidgets('deletes an entry after a confirmation', (tester) async {
    final api = await open(tester, [
      entry(1, 'Hades'),
      entry(2, 'Hades'),
      entry(3, 'Celeste'),
    ]);

    await tester.tap(find.byKey(const Key('duplicate-delete-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();

    expect(api.calls, contains('delete 2'));
    expect(find.text('No duplicates found'), findsOneWidget);
    await dismissToast(tester);
  });

  testWidgets('keeps the entry when the confirmation is cancelled', (
    tester,
  ) async {
    final api = await open(tester, [entry(1, 'Hades'), entry(2, 'Hades')]);

    await tester.tap(find.byKey(const Key('duplicate-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(api.calls.where((c) => c.startsWith('delete')), isEmpty);
    expect(find.byKey(const Key('duplicate-entry-1')), findsOneWidget);
  });
}
