import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

BoxDecoration surfaceOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(const Key('button-surface')),
  );
  return box.decoration as BoxDecoration;
}

Color labelColor(WidgetTester tester, String label) {
  return tester.widget<Text>(find.text(label)).style!.color!;
}

Future<void> hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump();
}

void main() {
  final tokens = tokensOf('shelfOled');

  group('ShelfButton', () {
    testWidgets('is 32 high with the control radius', (tester) async {
      await pumpThemed(tester, ShelfButton(label: 'Save', onPressed: () {}));

      expect(tester.getSize(find.byType(ShelfButton)).height, 32);
      expect(surfaceOf(tester).borderRadius, BorderRadius.circular(8));
    });

    testWidgets('fills a primary button with the accent gradient', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ShelfButton(
          label: 'Save',
          kind: ShelfButtonKind.primary,
          onPressed: () {},
        ),
      );

      final gradient = surfaceOf(tester).gradient! as LinearGradient;
      expect(gradient.colors, [tokens.accentA, tokens.accentB]);
      expect(labelColor(tester, 'Save'), tokens.onAccent);
    });

    testWidgets(
      'outlines a secondary button with the strong border and lifts it on hover',
      (tester) async {
        await pumpThemed(
          tester,
          ShelfButton(label: 'Cancel', onPressed: () {}),
        );
        expect(
          (surfaceOf(tester).border! as Border).top.color,
          tokens.borderStrong,
        );
        expect(surfaceOf(tester).color, isNull);

        await hover(tester, find.byType(ShelfButton));

        expect(surfaceOf(tester).color, tokens.surface2);
        expect((surfaceOf(tester).border! as Border).top.color, tokens.glow);
      },
    );

    testWidgets('writes a quiet button in muted text without a border', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ShelfButton(
          label: 'Skip',
          kind: ShelfButtonKind.quiet,
          onPressed: () {},
        ),
      );

      expect(surfaceOf(tester).border, isNull);
      expect(labelColor(tester, 'Skip'), tokens.muted);

      await hover(tester, find.byType(ShelfButton));

      expect(labelColor(tester, 'Skip'), tokens.foreground);
    });

    testWidgets('writes a danger button in the danger colour', (tester) async {
      await pumpThemed(
        tester,
        ShelfButton(
          label: 'Delete',
          kind: ShelfButtonKind.danger,
          onPressed: () {},
        ),
      );

      expect(labelColor(tester, 'Delete'), tokens.danger);
    });

    testWidgets('shows an icon before the label', (tester) async {
      await pumpThemed(
        tester,
        ShelfButton(label: 'Add', icon: Icons.add, onPressed: () {}),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(Icons.add)).dx,
        lessThan(tester.getCenter(find.text('Add')).dx),
      );
    });

    testWidgets('is dimmed to 40% and inert while disabled', (tester) async {
      await pumpThemed(
        tester,
        const ShelfButton(label: 'Save', onPressed: null),
      );

      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.4);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        ShelfButton(label: 'Save', onPressed: () => taps++),
      );

      await tester.tap(find.text('Save'));

      expect(taps, 1);
    });
  });

  group('ShelfIconButton', () {
    testWidgets('is a 32 px square with a tooltip', (tester) async {
      await pumpThemed(
        tester,
        ShelfIconButton(icon: Icons.close, tooltip: 'Close', onPressed: () {}),
      );

      expect(tester.getSize(find.byType(ShelfIconButton)), const Size(32, 32));
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'Close');
    });

    testWidgets('tints its background with the glow on hover', (tester) async {
      await pumpThemed(
        tester,
        ShelfIconButton(icon: Icons.close, tooltip: 'Close', onPressed: () {}),
      );
      expect(surfaceOf(tester).color, isNull);

      await hover(tester, find.byType(ShelfIconButton));

      expect(surfaceOf(tester).color, tokens.glowSoft);
    });
  });

  goldenInBothThemes(
    'buttons',
    () => Wrap(
      spacing: 12,
      runSpacing: 14,
      children: [
        ShelfButton(
          label: 'Primary',
          kind: ShelfButtonKind.primary,
          onPressed: () {},
        ),
        ShelfButton(label: 'Secondary', onPressed: () {}),
        ShelfButton(
          label: 'Quiet',
          kind: ShelfButtonKind.quiet,
          onPressed: () {},
        ),
        ShelfButton(
          label: 'Delete',
          kind: ShelfButtonKind.danger,
          onPressed: () {},
        ),
        ShelfButton(
          label: 'With icon',
          icon: Icons.add,
          kind: ShelfButtonKind.primary,
          onPressed: () {},
        ),
        const ShelfButton(
          label: 'Disabled',
          kind: ShelfButtonKind.primary,
          onPressed: null,
        ),
        const ShelfButton(label: 'Disabled', onPressed: null),
        ShelfIconButton(icon: Icons.close, tooltip: 'Close', onPressed: () {}),
      ],
    ),
    size: const Size(520, 140),
    width: 480,
  );
}
