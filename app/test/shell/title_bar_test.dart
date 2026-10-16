import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/shell/title_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfTokens get tokens => ShelfTokens.forTheme(resolveTheme('shelfOled', []));

Future<ProviderContainer> pumpBar(
  WidgetTester tester, {
  double width = 1200,
  bool minimal = false,
  TargetPlatform platform = TargetPlatform.windows,
}) async {
  tester.view.physicalSize = Size(width, 300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildShelfTheme(tokens).copyWith(platform: platform),
        home: Scaffold(
          backgroundColor: tokens.background,
          body: Align(
            alignment: Alignment.topLeft,
            child: TitleBar(location: '/library', minimal: minimal),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(TitleBar)));
}

Finder get field => find.byKey(const Key('search-field'));
Finder get title => find.byKey(const Key('title-bar-title'));

InputDecoration decoration(WidgetTester tester) =>
    tester.widget<TextField>(field).decoration!;

void main() {
  group('the search in the title bar', () {
    testWidgets('sits right after the page title', (tester) async {
      await pumpBar(tester);

      final gap = tester.getTopLeft(field).dx - tester.getTopRight(title).dx;
      expect(gap, inInclusiveRange(8, 40));
    });

    testWidgets('is 400 px wide at the smallest window and shrinks below', (
      tester,
    ) async {
      await pumpBar(tester, width: 1000);
      expect(tester.getSize(field).width, 400);

      await pumpBar(tester, width: 640);
      expect(tester.getSize(field).width, inExclusiveRange(150, 400));
    });

    testWidgets('keeps the room for the caption buttons', (tester) async {
      await pumpBar(tester, width: 640);

      expect(
        tester.getTopRight(field).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('caption-minimize'))).dx,
        ),
      );
    });

    testWidgets('has no search in the minimal bar', (tester) async {
      await pumpBar(tester, minimal: true);

      expect(field, findsNothing);
    });

    testWidgets('is 34 px high with an opaque fill and a visible border', (
      tester,
    ) async {
      await pumpBar(tester);

      expect(tester.getSize(field).height, 34);
      final look = decoration(tester);
      expect(look.fillColor!.a, 1);
      final border = look.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, tokens.borderStrong);
      final focused = look.focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.color, tokens.glow);
    });

    testWidgets('lights its border in the accent colour on hover', (
      tester,
    ) async {
      await pumpBar(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);

      await mouse.moveTo(tester.getCenter(field));
      await tester.pump();

      final border = decoration(tester).enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, tokens.accent);
    });
  });

  group('golden of the title bar', () {
    for (final width in [1440.0, 1000.0]) {
      testWidgets('at ${width.toInt()} px', tags: 'golden', (tester) async {
        await pumpBar(tester, width: width);

        await expectLater(
          find.byType(TitleBar),
          matchesGoldenFile('goldens/title_bar_${width.toInt()}.png'),
        );
      });
    }
  });
}
