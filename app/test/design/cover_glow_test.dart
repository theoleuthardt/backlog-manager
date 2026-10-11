import 'dart:typed_data';

import 'package:backlog_manager/design/cover_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widgets/harness.dart';

Uint8List pixels(List<List<int>> rgba) =>
    Uint8List.fromList([for (final p in rgba) ...p]);

void main() {
  group('glowColorFromPixels', () {
    test('takes the hue of a red picture and makes it bright', () {
      final color = glowColorFromPixels(
        pixels([
          [180, 20, 20, 255],
          [200, 30, 25, 255],
        ]),
      )!;
      final hsl = HSLColor.fromColor(color);

      expect(hsl.hue, lessThan(12));
      expect(hsl.saturation, greaterThanOrEqualTo(0.55));
      expect(hsl.lightness, inInclusiveRange(0.5, 0.62));
    });

    test('ignores grey and black, so a dark frame does not decide', () {
      final color = glowColorFromPixels(
        pixels([
          [10, 10, 10, 255],
          [128, 128, 128, 255],
          [20, 60, 200, 255],
        ]),
      )!;

      expect(HSLColor.fromColor(color).hue, inInclusiveRange(215, 235));
    });

    test('has no colour for a grey or transparent picture', () {
      expect(
        glowColorFromPixels(
          pixels([
            [90, 90, 90, 255],
            [255, 0, 0, 0],
          ]),
        ),
        isNull,
      );
    });
  });

  group('CoverGlow', () {
    testWidgets('lights the cover and the header in the theme glow', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const CoverGlow(
          coverSize: Size(100, 150),
          child: SizedBox(width: 300, height: 150),
        ),
        width: 400,
      );

      expect(find.byKey(const Key('cover-glow-halo')), findsOneWidget);
      expect(find.byKey(const Key('cover-glow-wash')), findsOneWidget);
      expect(find.byKey(const Key('cover-glow-veil')), findsOneWidget);
      final halo = tester.widget<DecoratedBox>(
        find.byKey(const Key('cover-glow-halo')),
      );
      final shadow = (halo.decoration as BoxDecoration).boxShadow!.single;
      expect(shadow.color.a, greaterThan(0));
      expect(
        tester.getSize(find.byKey(const Key('cover-glow-halo'))),
        const Size(100, 150),
      );
    });
  });
}
