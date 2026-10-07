import 'dart:ui';

import 'package:backlog_manager/design/color_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('colorFromHex and hexOf', () {
    test('read a #rrggbb colour', () {
      expect(colorFromHex('#f5a524'), const Color(0xFFF5A524));
      expect(colorFromHex('#000000'), const Color(0xFF000000));
    });

    test('read anything that is not #rrggbb as neutral grey', () {
      const grey = Color(0xFF808080);

      expect(colorFromHex('not a colour'), grey);
      expect(colorFromHex('#fff'), grey);
      expect(colorFromHex('#12345g'), grey);
      expect(colorFromHex(''), grey);
    });

    test('write a colour back as lower-case #rrggbb', () {
      expect(hexOf(const Color(0xFFF5A524)), '#f5a524');
      expect(hexOf(const Color(0xFF000000)), '#000000');
    });
  });

  group('mix', () {
    test('returns the first colour for 0 and the second for 1', () {
      const a = Color(0xFF102030);
      const b = Color(0xFFF0E0D0);

      expect(mix(a, b, 0), a);
      expect(mix(a, b, 1), b);
    });

    test('blends each channel by the given share of the second colour', () {
      expect(
        mix(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5),
        const Color(0xFF808080),
      );
      expect(
        mix(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.2),
        const Color(0xFF333333),
      );
    });
  });

  group('atOpacity', () {
    test('keeps the colour and sets the opacity', () {
      final result = atOpacity(const Color(0xFFF5A524), 0.14);

      expect(result.toARGB32() & 0x00FFFFFF, 0xF5A524);
      expect(result.a, closeTo(0.14, 0.01));
    });
  });

  group('onColorFor', () {
    test('picks black on a light colour and white on a dark one', () {
      expect(onColorFor(const Color(0xFFA3FF12)), const Color(0xFF000000));
      expect(onColorFor(const Color(0xFF1D2B8F)), const Color(0xFFFFFFFF));
    });

    test('always reaches 4.5:1 against the colour it is chosen for', () {
      for (var value = 0; value <= 255; value += 5) {
        final background = Color.fromARGB(255, value, 255 - value, value ~/ 2);

        expect(
          contrastRatio(onColorFor(background), background),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('contrastRatio', () {
    test('is 21 for black on white and 1 for the same colour', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.001),
      );
      expect(
        contrastRatio(const Color(0xFF123456), const Color(0xFF123456)),
        closeTo(1, 0.001),
      );
    });

    test('does not depend on the order of the colours', () {
      const a = Color(0xFF777777);
      const b = Color(0xFF000000);

      expect(contrastRatio(a, b), contrastRatio(b, a));
    });
  });
}
