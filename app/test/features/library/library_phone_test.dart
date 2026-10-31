import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import 'library_page_test.dart' show backlog, pumpLibrary;

const _phone = Size(402, 874);
const _handheld = Size(732, 412);

Future<void> openOnHandheld(WidgetTester tester) async {
  await pumpLibrary(
    tester,
    FakeBacklogApi(entries: backlog),
    overrides: [
      isDesktopProvider.overrideWithValue(false),
      sessionUserProvider.overrideWithValue(
        const SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
          steamId: '76561198000000000',
        ),
      ),
    ],
  );
  tester.view.physicalSize = _handheld;
  await tester.pumpAndSettle();
}

Future<void> openOnPhone(WidgetTester tester) async {
  await pumpLibrary(
    tester,
    FakeBacklogApi(entries: backlog),
    overrides: [isDesktopProvider.overrideWithValue(false)],
  );
  tester.view.physicalSize = _phone;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the library actions are a labelled menu on a phone', (
    tester,
  ) async {
    await openOnPhone(tester);

    expect(find.byKey(const Key('random-pull-button')), findsNothing);
    await tester.tap(find.byKey(const Key('library-actions')));
    await tester.pumpAndSettle();

    for (final label in [
      'Sync IGDB data',
      'Pull a random game',
      'Find duplicate games',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Pull a random game'));
    await tester.pumpAndSettle();
    expect(find.text('Random Pull'), findsWidgets);
  });

  testWidgets('the filter bar gives the filters a row of their own', (
    tester,
  ) async {
    await openOnPhone(tester);

    final add = tester.getRect(find.text('+ Add filter'));
    final owned = tester.getRect(find.byKey(const Key('owned-only')));
    expect(owned.top, greaterThanOrEqualTo(add.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the covers can be made smaller and bigger', (tester) async {
    await openOnPhone(tester);
    double coverWidth() => tester.getSize(find.byType(ShelfCover).first).width;
    final medium = coverWidth();

    await tester.tap(find.byKey(const Key('library-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Small').last);
    await tester.pumpAndSettle();
    final small = coverWidth();

    await tester.tap(find.byKey(const Key('library-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large').last);
    await tester.pumpAndSettle();
    final large = coverWidth();

    expect(small, lessThan(medium));
    expect(large, greaterThan(medium));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a handheld has the actions in one menu, Steam sync too', (
    tester,
  ) async {
    await openOnHandheld(tester);

    for (final key in [
      'steam-sync-button',
      'igdb-sync-button',
      'random-pull-button',
      'duplicates-button',
    ]) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
    await tester.tap(find.byKey(const Key('library-actions')));
    await tester.pumpAndSettle();
    for (final label in [
      'Sync Steam playtime',
      'Sync IGDB data',
      'Pull a random game',
      'Find duplicate games',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('a handheld leaves the filters room and names Owned Only', (
    tester,
  ) async {
    await openOnHandheld(tester);
    final bar = find.byKey(const Key('filter-bar'));

    expect(
      find.descendant(of: bar, matching: find.text('Owned Only')),
      findsOneWidget,
    );
    expect(find.textContaining('Sort:'), findsNothing);
    expect(find.byKey(const Key('library-view-menu')), findsOneWidget);
    final add = tester.getRect(find.text('+ Add filter'));
    final owned = tester.getRect(
      find.descendant(of: bar, matching: find.text('Owned Only')),
    );
    expect(
      owned.left - add.left,
      greaterThan(tester.getSize(bar).width * 0.25),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the desktop keeps its toolbar', (tester) async {
    await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

    expect(find.byKey(const Key('random-pull-button')), findsOneWidget);
    expect(find.byKey(const Key('library-actions')), findsNothing);
  });
}
