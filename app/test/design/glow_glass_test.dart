import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfTokens tokensOf(String id) => ShelfTokens.forTheme(resolveTheme(id, []));

Widget host(Widget child, {String themeId = 'shelfOled'}) {
  return MaterialApp(
    theme: buildShelfTheme(tokensOf(themeId)),
    home: Scaffold(body: child),
  );
}

void main() {
  final tokens = tokensOf('shelfOled');

  group('ShelfGlow', () {
    test('fills a primary button with the accent gradient and a glow', () {
      final decoration = ShelfGlow.primaryButton(tokens, radius: 8);
      final gradient = decoration.gradient! as LinearGradient;

      expect(gradient.colors, [tokens.accentA, tokens.accentB]);
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(decoration.boxShadow!.single.color, tokens.accentGlow);
      expect(decoration.boxShadow!.single.blurRadius, 22);
    });

    test('runs the progress gradient from left to right with a small glow', () {
      final decoration = ShelfGlow.progress(tokens);
      final gradient = decoration.gradient! as LinearGradient;

      expect(gradient.colors, [tokens.accentA, tokens.accentB]);
      expect(gradient.begin, Alignment.centerLeft);
      expect(gradient.end, Alignment.centerRight);
      expect(decoration.boxShadow!.single.blurRadius, 10);
    });

    test('casts the cover shadow in the glow colour', () {
      final shadow = ShelfGlow.coverShadow(tokens).single;

      expect(shadow.color.toARGB32() & 0xFFFFFF, 0x3B82F6);
      expect(shadow.offset, const Offset(0, 14));
      expect(shadow.blurRadius, 34);
      expect(shadow.spreadRadius, -14);
    });

    test('outlines a selected cover in the accent with a glow', () {
      final decoration = ShelfGlow.selectedRing(tokens, radius: 12);
      final border = decoration.border! as Border;

      expect(border.top.color, tokens.accent);
      expect(border.top.width, 3);
      expect(decoration.boxShadow!.single.blurRadius, 28);
    });

    test('lets the switch glow in the accent', () {
      expect(ShelfGlow.switchOn(tokens).single.color, tokens.accentGlow);
      expect(ShelfGlow.switchOn(tokens).single.blurRadius, 12);
    });
  });

  group('EdgeLine', () {
    LinearGradient gradientOf(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(EdgeLine),
          matching: find.byType(DecoratedBox),
        ),
      );
      return (box.decoration as BoxDecoration).gradient! as LinearGradient;
    }

    testWidgets('glows in the middle of a bar edge', (tester) async {
      await tester.pumpWidget(
        host(const EdgeLine.glowInMiddle(axis: Axis.horizontal)),
      );

      expect(gradientOf(tester).colors, [
        tokens.borderSubtle,
        tokens.glow,
        tokens.borderSubtle,
      ]);
    });

    testWidgets('fades from the glow to the border along a pane edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const EdgeLine.fadeFromGlow(axis: Axis.vertical)),
      );

      expect(gradientOf(tester).colors, [tokens.glow, tokens.borderSubtle]);
      expect(gradientOf(tester).begin, Alignment.topCenter);
    });

    testWidgets('is one logical pixel thick', (tester) async {
      await tester.pumpWidget(
        host(const EdgeLine.glowInMiddle(axis: Axis.horizontal)),
      );

      expect(tester.getSize(find.byType(EdgeLine)).height, 1);
    });
  });

  group('GlassSurface', () {
    testWidgets('blurs what is behind it by default', (tester) async {
      await tester.pumpWidget(
        host(const GlassSurface(opacity: 0.42, blur: 14, child: Text('Bar'))),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Bar'), findsOneWidget);
    });

    testWidgets('skips the blur when it is switched off', (tester) async {
      await tester.pumpWidget(
        host(
          const AtmosphereSettings(
            blurEnabled: false,
            child: GlassSurface(opacity: 0.42, blur: 14, child: Text('Bar')),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Bar'), findsOneWidget);
    });

    testWidgets('tints the glass with the background at the given opacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AtmosphereSettings(
            blurEnabled: false,
            child: GlassSurface(opacity: 0.5, blur: 10, child: SizedBox()),
          ),
        ),
      );

      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(ColoredBox),
        ),
      );

      expect(
        box.color.toARGB32() & 0xFFFFFF,
        tokens.background.toARGB32() & 0xFFFFFF,
      );
      expect(box.color.a, closeTo(0.5, 0.01));
    });
  });
}
