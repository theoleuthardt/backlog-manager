import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/library/reveal_entry.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import 'library_page_test.dart' show pumpLibrary;

List<BacklogEntry> many(int count) => [
  for (var id = 1; id <= count; id++)
    BacklogEntry(id: id, title: 'Game $id', status: 'Not Started'),
];

void main() {
  testWidgets('a game far down its group is shown and outlined', (
    tester,
  ) async {
    final container = await pumpLibrary(
      tester,
      FakeBacklogApi(entries: many(150)),
      height: 900,
    );
    expect(find.byKey(const ValueKey('tile-140')), findsNothing);

    container.read(routerProvider).go('/library?entry=140');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('tile-140')), findsOneWidget);
    expect(container.read(revealedEntryProvider)!.id, 140);
    expect(find.byKey(const Key('cover-ring')), findsOneWidget);

    await tester.pump(revealDuration + const Duration(milliseconds: 100));
    expect(container.read(revealedEntryProvider), isNull);
  });

  testWidgets('a game 1,250 entries down is scrolled to and on screen', (
    tester,
  ) async {
    final container = await pumpLibrary(
      tester,
      FakeBacklogApi(entries: many(1300)),
      height: 900,
    );

    container.read(routerProvider).go('/library?entry=1250');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final tile = find.byKey(const ValueKey('tile-1250'));
    expect(tile, findsOneWidget);
    expect(find.byKey(const Key('cover-ring')), findsOneWidget);
    final center = tester.getCenter(tile);
    expect(center.dy, inInclusiveRange(0, 900));
    await tester.pump(revealDuration + const Duration(milliseconds: 100));
  });

  testWidgets('asking again for the open game points at it again', (
    tester,
  ) async {
    final container = await pumpLibrary(
      tester,
      FakeBacklogApi(entries: many(20)),
    );
    container.read(routerProvider).go('/library?entry=5');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pump(revealDuration + const Duration(milliseconds: 100));
    expect(container.read(revealedEntryProvider), isNull);

    container.read(revealRequestProvider.notifier).request(5);
    await tester.pump();
    await tester.pump();

    expect(container.read(revealedEntryProvider)!.id, 5);
    await tester.pump(revealDuration + const Duration(milliseconds: 100));
  });

  testWidgets('a folded group opens for the game', (tester) async {
    final container = await pumpLibrary(
      tester,
      FakeBacklogApi(entries: many(5)),
    );
    await tester.tap(find.byKey(const Key('group-toggle-status:Not Started')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tile-3')), findsNothing);

    container.read(routerProvider).go('/library?entry=3');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('tile-3')), findsOneWidget);
    await tester.pump(revealDuration + const Duration(milliseconds: 100));
  });
}
