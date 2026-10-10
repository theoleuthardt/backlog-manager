import 'package:backlog_manager/design/widgets/color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const palette = ['#38bdf8', '#4ade80', '#f87171'];

Future<List<String>> pump(
  WidgetTester tester, {
  String value = '#38bdf8',
}) async {
  final picked = <String>[];
  await pumpThemed(
    tester,
    ShelfColorPicker(
      value: value,
      palette: palette,
      label: 'Category colour',
      onChanged: picked.add,
    ),
  );
  return picked;
}

void main() {
  group('ShelfColorPicker', () {
    testWidgets('shows the current colour as a swatch', (tester) async {
      await pump(tester, value: '#4ade80');

      final swatch = tester.widget<DecoratedBox>(
        find.byKey(const Key('color-picker-swatch')),
      );
      expect(
        (swatch.decoration as BoxDecoration).color,
        const Color(0xFF4ADE80),
      );
    });

    testWidgets('picks a colour of the palette', (tester) async {
      final picked = await pump(tester);

      await tester.tap(find.byKey(const Key('color-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('color-option-#f87171')));
      await tester.pumpAndSettle();

      expect(picked, ['#f87171']);
    });

    testWidgets('takes a hex colour typed in', (tester) async {
      final picked = await pump(tester);

      await tester.tap(find.byKey(const Key('color-picker')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('color-hex-field')),
        '#A1B2C3',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(picked, ['#a1b2c3']);
    });

    testWidgets('ignores text that is not a #rrggbb colour', (tester) async {
      final picked = await pump(tester);

      await tester.tap(find.byKey(const Key('color-picker')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('color-hex-field')), '#12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(picked, isEmpty);
    });

    testWidgets('marks the current colour in the palette', (tester) async {
      await pump(tester, value: '#4ade80');

      await tester.tap(find.byKey(const Key('color-picker')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('color-option-#4ade80')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('color-option-#38bdf8')),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    });
  });

  goldenInBothThemes(
    'color_palette',
    () => ShelfColorPalette(
      value: '#4ade80',
      palette: palette,
      onChanged: (_) {},
    ),
    size: const Size(260, 140),
  );
}
