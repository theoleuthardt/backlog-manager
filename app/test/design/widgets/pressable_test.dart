import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Widget probe({
  VoidCallback? onPressed,
  void Function(ShelfInteraction)? onState,
}) {
  return ShelfPressable(
    onPressed: onPressed,
    semanticLabel: 'Probe',
    builder: (context, state) {
      onState?.call(state);
      return const SizedBox(width: 100, height: 40);
    },
  );
}

void main() {
  testWidgets('calls onPressed when tapped', (tester) async {
    var taps = 0;
    await pumpThemed(tester, probe(onPressed: () => taps++));

    await tester.tap(find.byType(ShelfPressable));

    expect(taps, 1);
  });

  testWidgets('does nothing while it is disabled', (tester) async {
    late ShelfInteraction seen;
    await pumpThemed(tester, probe(onState: (s) => seen = s));

    await tester.tap(find.byType(ShelfPressable));

    expect(seen.enabled, isFalse);
  });

  testWidgets('reports a hovering mouse', (tester) async {
    late ShelfInteraction seen;
    await pumpThemed(tester, probe(onPressed: () {}, onState: (s) => seen = s));
    expect(seen.hovered, isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(ShelfPressable)));
    await tester.pump();

    expect(seen.hovered, isTrue);
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump();
    expect(seen.hovered, isFalse);
  });

  testWidgets('reports a press while the pointer is down', (tester) async {
    late ShelfInteraction seen;
    await pumpThemed(tester, probe(onPressed: () {}, onState: (s) => seen = s));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ShelfPressable)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(seen.pressed, isTrue);

    await gesture.up();
    await tester.pump();
    expect(seen.pressed, isFalse);
  });

  testWidgets(
    'shows a focus ring for keyboard focus and activates with Enter and Space',
    (tester) async {
      var presses = 0;
      await pumpThemed(tester, probe(onPressed: () => presses++));
      expect(find.byKey(const Key('focus-ring')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.byKey(const Key('focus-ring')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(presses, 2);
    },
  );

  testWidgets('is a labelled button for assistive technology', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(tester, probe(onPressed: () {}));

    expect(
      tester.getSemantics(find.byType(ShelfPressable)),
      isSemantics(isButton: true, isEnabled: true, label: 'Probe'),
    );
    handle.dispose();
  });

  testWidgets('does not take focus while it is disabled', (tester) async {
    await pumpThemed(tester, probe());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(find.byKey(const Key('focus-ring')), findsNothing);
  });
}
