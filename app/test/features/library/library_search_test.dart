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
    testWidgets('stands right of the heading, on its line', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));

      final heading = inLibrary(find.text('Library'));
      expect(inLibrary(field), findsOneWidget);
      expect(
        tester.getTopLeft(field).dx,
        greaterThan(tester.getTopRight(heading).dx),
      );
      expect(
        (tester.getCenter(field).dy - tester.getCenter(heading).dy).abs(),
        lessThan(8),
      );
      expect(
        tester.getTopRight(field).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('add-game-button'))).dx,
        ),
      );
    });

    testWidgets('is centred between the heading and the Add Game button', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));

      final heading = inLibrary(find.text('Library'));
      final add = find.byKey(const Key('add-game-button'));
      final between =
          (tester.getTopRight(heading).dx + tester.getTopLeft(add).dx) / 2;

      expect(tester.getCenter(field).dx, closeTo(between, 16));
    });

    testWidgets('is above the controls and the counts', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));

      expect(
        tester.getBottomLeft(field).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('select-toggle'))).dy),
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

    testWidgets('shows the shortcut that focuses it', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));

      expect(
        find.descendant(of: field, matching: find.text('Ctrl S')),
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

    testWidgets('is focused by Ctrl+S', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    });

    testWidgets('takes a line of its own above the controls in a narrow pane', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: [hades]));
      final headingTop = tester.getTopLeft(inLibrary(find.text('Library'))).dy;

      tester.view.physicalSize = const Size(800, 2400);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(field).dy, greaterThan(headingTop + 20));
      expect(
        tester.getBottomLeft(field).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('select-toggle'))).dy),
      );
      expect(tester.getSize(field).width, greaterThan(300));
    });
  });
}
