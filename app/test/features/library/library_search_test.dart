import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import 'library_page_test.dart' show inLibrary, pumpLibrary;

const hades = BacklogEntry(
  id: 1,
  title: 'Hades',
  status: 'In Progress',
  owned: true,
  interest: 6,
);

Finder get field => find.byKey(const Key('search-field'));

InputDecoration decoration(WidgetTester tester) =>
    tester.widget<TextField>(field).decoration!;

void main() {
  group('the search in the library header', () {
    testWidgets('stands in the header row, right of the counts', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));

      expect(inLibrary(field), findsOneWidget);
      final counts = find.textContaining('games');
      expect(
        tester.getTopLeft(field).dx,
        greaterThan(tester.getTopRight(counts.first).dx),
      );
      expect(
        tester.getTopLeft(field).dy,
        lessThan(tester.getTopLeft(find.text('In Progress').first).dy),
      );
    });

    testWidgets('is not in the title bar', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));

      expect(
        find.descendant(
          of: find.byKey(const Key('title-bar')),
          matching: field,
        ),
        findsNothing,
      );
    });

    testWidgets('is 34 px high with an opaque fill and a visible border', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));
      final tokens = Theme.of(tester.element(field)).extension<ShelfTokens>()!;

      expect(tester.getSize(field).height, 34);
      final look = decoration(tester);
      expect(look.fillColor!.a, 1);
      expect(
        (look.enabledBorder! as OutlineInputBorder).borderSide.color,
        tokens.borderStrong,
      );
      expect(
        (look.focusedBorder! as OutlineInputBorder).borderSide.color,
        tokens.glow,
      );
    });

    testWidgets('lights its border in the accent colour on hover', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));
      final tokens = Theme.of(tester.element(field)).extension<ShelfTokens>()!;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);

      await mouse.moveTo(tester.getCenter(field));
      await tester.pump();

      expect(
        (decoration(tester).enabledBorder! as OutlineInputBorder)
            .borderSide
            .color,
        tokens.accent,
      );
    });

    testWidgets('shows the key that focuses it', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));

      expect(
        find.descendant(of: field, matching: find.text('/')),
        findsOneWidget,
      );
    });

    testWidgets('filters the library as you type', (tester) async {
      final container = await pumpLibrary(
        tester,
        FakeBacklogApi(entries: [hades]),
      );

      await tester.enterText(field, 'had');
      await tester.pump();

      expect(container.read(filtersProvider).search, 'had');
    });

    testWidgets('is focused by the / key', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();

      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    });

    testWidgets('moves below the other controls when the pane is narrow', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));
      final wideTop = tester.getTopLeft(field).dy;

      tester.view.physicalSize = const Size(1000, 2400);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(field).dy, greaterThan(wideTop));
      expect(
        tester.getTopRight(field).dx,
        lessThanOrEqualTo(tester.getSize(find.byType(MaterialApp)).width),
      );
    });
  });
}
