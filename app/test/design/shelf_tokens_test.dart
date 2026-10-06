import 'dart:ui';

import 'package:backlog_manager/design/builtin_tokens.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfTokens tokensOf(String id) => ShelfTokens.forTheme(resolveTheme(id, []));

ThemeColors colors({
  String background = '#000000',
  String surface = '#0b0b0e',
  String foreground = '#f2f2f3',
  String accent = '#f5a524',
  String border = '#353a4c',
  String glow = '#3b82f6',
}) {
  return ThemeColors(
    background: background,
    surface: surface,
    foreground: foreground,
    accent: accent,
    border: border,
    glow: glow,
  );
}

int channelDistance(Color a, Color b) {
  int channel(Color c, int shift) => (c.toARGB32() >> shift) & 0xFF;
  return [16, 8, 0]
      .map((shift) => (channel(a, shift) - channel(b, shift)).abs())
      .reduce((a, b) => a > b ? a : b);
}

void main() {
  group('Shelf OLED, the documented table', () {
    final tokens = tokensOf('shelfOled');

    test('has the six input colours of the design', () {
      expect(tokens.background, const Color(0xFF000000));
      expect(tokens.surface, const Color(0xFF0B0B0E));
      expect(tokens.foreground, const Color(0xFFF2F2F3));
      expect(tokens.accent, const Color(0xFFF5A524));
      expect(tokens.borderStrong, const Color(0xFF353A4C));
      expect(tokens.glow, const Color(0xFF3B82F6));
    });

    test('has the documented derived values', () {
      expect(tokens.surface2, const Color(0xFF121216));
      expect(tokens.surface3, const Color(0xFF1A1A20));
      expect(tokens.borderSubtle, const Color(0xFF1B1D28));
      expect(tokens.text2, const Color(0xFFD9D9DD));
      expect(tokens.muted, const Color(0xFFA3A5AD));
      expect(tokens.faint, const Color(0xFF7B7D87));
      expect(tokens.onAccent, const Color(0xFF1A1103));
      expect(tokens.accentSoft, const Color.fromRGBO(245, 165, 36, 0.14));
      expect(tokens.glowSoft, const Color.fromRGBO(59, 130, 246, 0.13));
    });

    test('has the semantic colours of a dark theme', () {
      expect(tokens.success, const Color(0xFF34D399));
      expect(tokens.danger, const Color(0xFFFF6B81));
      expect(tokens.info, const Color(0xFF60A5FA));
    });
  });

  group('ShelfTokens.fromColors', () {
    final derived = ShelfTokens.fromColors(colors());
    final documented = tokensOf('shelfOled');

    test('keeps the input colours', () {
      expect(derived.background, documented.background);
      expect(derived.surface, documented.surface);
      expect(derived.foreground, documented.foreground);
      expect(derived.accent, documented.accent);
      expect(derived.glow, documented.glow);
    });

    test('derives values close to the hand-tuned table of Shelf OLED', () {
      expect(
        channelDistance(derived.surface2, documented.surface2),
        lessThan(17),
      );
      expect(
        channelDistance(derived.surface3, documented.surface3),
        lessThan(17),
      );
      expect(
        channelDistance(derived.borderSubtle, documented.borderSubtle),
        lessThan(17),
      );
      expect(channelDistance(derived.text2, documented.text2), lessThan(17));
      expect(channelDistance(derived.muted, documented.muted), lessThan(17));
      expect(channelDistance(derived.faint, documented.faint), lessThan(17));
    });

    test('mixes the surface variants by the documented shares', () {
      final surface = colorFromHex('#0b0b0e');
      final foreground = colorFromHex('#f2f2f3');

      expect(derived.surface2, mix(surface, foreground, 0.03));
      expect(derived.surface3, mix(surface, foreground, 0.06));
      expect(derived.borderSubtle, mix(surface, foreground, 0.08));
    });

    test('mixes the text colours towards the background', () {
      final background = colorFromHex('#000000');
      final foreground = colorFromHex('#f2f2f3');

      expect(derived.text2, mix(foreground, background, 0.11));
      expect(derived.muted, mix(foreground, background, 0.35));
      expect(derived.faint, mix(foreground, background, 0.50));
    });

    test('sets accentSoft to 14% and glowSoft to 16% opacity', () {
      expect(derived.accentSoft.a, closeTo(0.14, 0.01));
      expect(derived.glowSoft.a, closeTo(0.16, 0.01));
      expect(derived.accentSoft.toARGB32() & 0xFFFFFF, 0xF5A524);
    });

    test('keeps a calm border as it is', () {
      expect(derived.borderStrong, const Color(0xFF353A4C));
    });

    test('blends a loud white border into the background at 20%', () {
      final tokens = ShelfTokens.fromColors(colors(border: '#ffffff'));

      expect(tokens.borderStrong, const Color(0xFF333333));
    });

    test('blends a loud near-black border on a light theme', () {
      final tokens = ShelfTokens.fromColors(
        colors(
          background: '#f5f4ef',
          surface: '#ffffff',
          foreground: '#15151b',
          border: '#15151b',
        ),
      );

      expect(
        tokens.borderStrong,
        mix(colorFromHex('#f5f4ef'), colorFromHex('#15151b'), 0.2),
      );
    });

    test('blends a neon border into the background at 55%', () {
      final tokens = ShelfTokens.fromColors(
        colors(background: '#04040e', border: '#00ffd0'),
      );

      expect(
        tokens.borderStrong,
        mix(colorFromHex('#04040e'), colorFromHex('#00ffd0'), 0.55),
      );
    });

    test('picks black text on a light accent and white on a dark one', () {
      expect(
        ShelfTokens.fromColors(colors(accent: '#a3ff12')).onAccent,
        const Color(0xFF000000),
      );
      expect(
        ShelfTokens.fromColors(colors(accent: '#1d2b8f')).onAccent,
        const Color(0xFFFFFFFF),
      );
    });

    test('uses the semantic colours of the lightness of the theme', () {
      final light = ShelfTokens.fromColors(
        colors(
          background: '#f5f4ef',
          surface: '#ffffff',
          foreground: '#15151b',
          border: '#c9c7bb',
        ),
      );

      expect(light.success, const Color(0xFF047857));
      expect(light.danger, const Color(0xFFE11D48));
      expect(light.info, const Color(0xFF4F46E5));
      expect(derived.success, const Color(0xFF34D399));
    });

    test('derives the atmosphere from the six colours', () {
      expect(derived.starA.toARGB32() & 0xFFFFFF, 0xF2F2F3);
      expect(derived.starA.a, closeTo(0.8, 0.01));
      expect(derived.starB.toARGB32() & 0xFFFFFF, 0xF5A524);
      expect(derived.starC.toARGB32() & 0xFFFFFF, 0x3B82F6);
      expect(derived.nebula1.toARGB32() & 0xFFFFFF, 0x3B82F6);
      expect(derived.nebula1.a, closeTo(0.30, 0.01));
      expect(derived.nebula2.toARGB32() & 0xFFFFFF, 0xF5A524);
      expect(derived.sky.toARGB32() & 0xFFFFFF, 0x3B82F6);
    });
  });

  group('ShelfTokens.forTheme', () {
    test('uses the tuned tokens of every built-in theme with an entry', () {
      for (final id in ['shelfOled', 'light', 'colorful', 'freaky']) {
        expect(tokensOf(id), builtinShelfTokens[id], reason: id);
      }
    });

    test('derives the tokens of the classic dark theme from its colours', () {
      final dark = tokensOf('dark');

      expect(dark.background, const Color(0xFF000000));
      expect(dark.accent, const Color(0xFF2563EB));
      expect(dark.borderStrong, const Color(0xFF333333));
    });

    test('derives the tokens of a custom theme', () {
      const custom = CustomTheme(
        id: 'custom-neon',
        name: 'Neon',
        colors: ThemeColors(
          background: '#0a0014',
          surface: '#1a0033',
          foreground: '#f5e9ff',
          accent: '#ff2bd6',
          border: '#5b2a86',
          glow: '#00e5ff',
        ),
      );

      final tokens = ShelfTokens.forTheme(
        resolveTheme('custom-neon', [custom]),
      );

      expect(tokens.accent, const Color(0xFFFF2BD6));
      expect(tokens.onAccent, const Color(0xFF000000));
    });
  });

  group('readable text in every built-in theme', () {
    for (final theme in builtinThemes) {
      final tokens = ShelfTokens.forTheme(resolveTheme(theme.id, []));

      for (final entry in {
        'foreground': tokens.foreground,
        'text2': tokens.text2,
        'muted': tokens.muted,
        'faint': tokens.faint,
      }.entries) {
        test('${theme.id}: ${entry.key} on the background reaches 4.5:1', () {
          expect(
            contrastRatio(entry.value, tokens.background),
            greaterThanOrEqualTo(4.5),
          );
        });
      }

      for (final entry in {
        'success': tokens.success,
        'danger': tokens.danger,
        'info': tokens.info,
      }.entries) {
        test('${theme.id}: ${entry.key} on the surface reaches 4.5:1', () {
          expect(
            contrastRatio(entry.value, tokens.surface),
            greaterThanOrEqualTo(4.5),
          );
        });
      }

      test('${theme.id}: text on the accent reaches 4.5:1', () {
        expect(
          contrastRatio(tokens.onAccent, tokens.accent),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('copyWith and lerp', () {
    final a = tokensOf('shelfOled');
    final b = tokensOf('light');

    test('copyWith replaces only the given colours', () {
      final changed = a.copyWith(accent: const Color(0xFF123456));

      expect(changed.accent, const Color(0xFF123456));
      expect(changed.background, a.background);
    });

    test('lerp returns the ends at 0 and 1', () {
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
    });

    test('lerp blends the colours in between', () {
      final middle = a.lerp(b, 0.5);

      expect(middle.background, Color.lerp(a.background, b.background, 0.5));
    });
  });
}
