import 'package:backlog_manager/design/focus_glide.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widgets/harness.dart';

Widget button(String key, {double width = 100}) => ShelfPressable(
  key: Key(key),
  onPressed: () {},
  semanticLabel: key,
  builder: (context, state) => SizedBox(width: width, height: 40),
);

Future<void> pumpGlide(
  WidgetTester tester, {
  bool reducedMotion = false,
  Widget? child,
}) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
  final tokens = tokensOf('shelfOled');
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        disableAnimations: reducedMotion,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildShelfTheme(tokens),
        builder: (context, app) =>
            FocusGlideHost(child: app ?? const SizedBox()),
        home: Material(
          color: tokens.background,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child:
                  child ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      button('first'),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          button('second'),
                          const SizedBox(width: 30),
                          button('third', width: 160),
                        ],
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    ),
  );
}

FocusGlideHostState host(WidgetTester tester) =>
    tester.state<FocusGlideHostState>(find.byType(FocusGlideHost));

/// Where the ring of the control [key] would be drawn.
Rect ringOf(WidgetTester tester, String key) => tester.getRect(
  find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(ShelfFocusRing),
  ),
);

Future<void> focus(WidgetTester tester, String key) async {
  Focus.of(
    tester.element(
      find
          .descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(GestureDetector),
          )
          .first,
    ),
  ).requestFocus();
  await tester.pump();
}

void main() {
  testWidgets('one ring glides to the focused control', (tester) async {
    await pumpGlide(tester);
    expect(host(tester).ringRect, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('focus-ring')), findsNothing);
    expect(
      host(tester).ringRect,
      rectMoreOrLessEquals(ringOf(tester, 'first'), epsilon: 0.5),
    );
  });

  testWidgets('moves through the space between two controls', (tester) async {
    await pumpGlide(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final from = ringOf(tester, 'first');
    final to = ringOf(tester, 'second');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final midway = host(tester).ringRect!;
    expect(midway.bottom, greaterThan(from.bottom), reason: 'the lead');
    expect(midway.bottom, lessThan(to.bottom));
    expect(midway.top, lessThan(to.top), reason: 'the trailing edge');

    await tester.pumpAndSettle();
    expect(host(tester).ringRect, rectMoreOrLessEquals(to, epsilon: 0.5));
  });

  testWidgets('takes the size of a wider control', (tester) async {
    await pumpGlide(tester);
    await focus(tester, 'second');
    await tester.pumpAndSettle();

    await focus(tester, 'third');
    await tester.pumpAndSettle();

    expect(
      host(tester).ringRect,
      rectMoreOrLessEquals(ringOf(tester, 'third'), epsilon: 0.5),
    );
  });

  testWidgets('fades out when the focus leaves', (tester) async {
    await pumpGlide(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(host(tester).ringRect, isNull);
  });

  testWidgets('jumps without motion when the system asks for less', (
    tester,
  ) async {
    await pumpGlide(tester, reducedMotion: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();

    expect(
      host(tester).ringRect,
      rectMoreOrLessEquals(ringOf(tester, 'first'), epsilon: 0.5),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();
    expect(
      host(tester).ringRect,
      rectMoreOrLessEquals(ringOf(tester, 'second'), epsilon: 0.5),
    );
  });

  testWidgets('follows a control that scrolls', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpGlide(
      tester,
      child: SizedBox(
        height: 300,
        width: 200,
        child: ListView(
          controller: controller,
          children: [
            for (var i = 0; i < 20; i++)
              Padding(
                padding: const EdgeInsets.all(8),
                child: button('item-$i'),
              ),
          ],
        ),
      ),
    );
    await focus(tester, 'item-2');
    await tester.pumpAndSettle();

    controller.jumpTo(40);
    await tester.pumpAndSettle();

    expect(
      host(tester).ringRect,
      rectMoreOrLessEquals(ringOf(tester, 'item-2'), epsilon: 0.5),
    );
  });

  testWidgets('golden: the ring on a control', tags: 'golden', (tester) async {
    await pumpGlide(tester);
    await focus(tester, 'third');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FocusGlideHost),
      matchesGoldenFile('goldens/focus_glide.png'),
    );
  });

  testWidgets(
    'golden: the ring stretching toward the next control',
    tags: 'golden',
    (tester) async {
      await pumpGlide(tester);
      await focus(tester, 'second');
      await tester.pumpAndSettle();

      await focus(tester, 'third');
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      await expectLater(
        find.byType(FocusGlideHost),
        matchesGoldenFile('goldens/focus_glide_moving.png'),
      );
    },
  );

  testWidgets('takes a new colour and corner of its control at once', (
    tester,
  ) async {
    final style = ValueNotifier<(Color, double)>((const Color(0xFFFF9800), 8));
    addTearDown(style.dispose);
    await pumpGlide(
      tester,
      child: SizedBox(
        width: 120,
        height: 50,
        child: ValueListenableBuilder(
          valueListenable: style,
          builder: (context, value, _) => ShelfFocusRing(
            visible: true,
            color: value.$1,
            borderRadius: value.$2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(host(tester).ringColor, const Color(0xFFFF9800));

    style.value = (const Color(0xFF009688), 20);
    await tester.pumpAndSettle();

    expect(host(tester).ringColor, const Color(0xFF009688));
    expect(host(tester).ringCorner, closeTo(20, 0.5));
  });

  testWidgets('without a host every control draws its own ring', (
    tester,
  ) async {
    await pumpThemed(tester, button('alone'));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('focus-ring')), findsOneWidget);
  });
}
