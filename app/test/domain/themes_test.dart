import 'dart:math';

import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter_test/flutter_test.dart';

const customTheme = CustomTheme(
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

void main() {
  group('resolveTheme', () {
    test('resolves a built-in theme by id', () {
      final theme = resolveTheme('light', []);

      expect(theme.id, 'light');
      expect(theme.builtin, isTrue);
    });

    test('resolves a custom theme by id', () {
      final theme = resolveTheme('custom-neon', [customTheme]);

      expect(theme.id, 'custom-neon');
      expect(theme.builtin, isFalse);
      expect(theme.colors.accent, '#ff2bd6');
    });

    test('falls back to the default theme for an unknown id', () {
      expect(resolveTheme('deleted-theme', []).id, defaultThemeId);
    });

    test('ships light, dark, colorful and freaky as built-in themes', () {
      expect(builtinThemes.map((theme) => theme.id), [
        'dark',
        'light',
        'colorful',
        'freaky',
      ]);
    });
  });

  group('onAccentColor', () {
    test('picks black text for a light accent', () {
      expect(onAccentColor('#ff2bd6'), '#000000');
    });

    test('picks white text for a dark accent', () {
      expect(onAccentColor('#1d2b8f'), '#ffffff');
    });
  });

  group('iconsNeedInversion', () {
    test('inverts the white icon set when the foreground colour is dark', () {
      expect(iconsNeedInversion(resolveTheme('light', []).colors), isTrue);
    });

    test('keeps the icons for a light foreground colour', () {
      expect(iconsNeedInversion(customTheme.colors), isFalse);
    });
  });

  group('isHexColor', () {
    for (final value in ['#000000', '#FfAa00', '#0a0014']) {
      test('accepts $value', () => expect(isHexColor(value), isTrue));
    }
    for (final value in ['#fff', 'red', '#gggggg', 'url(x)', '#0000000', '']) {
      test('rejects "$value"', () => expect(isHexColor(value), isFalse));
    }
  });

  group('newCustomThemeId', () {
    test('never collides with a built-in or existing custom theme id', () {
      final taken = [...builtinThemes.map((theme) => theme.id), 'custom-abc'];

      final id = newCustomThemeId(taken);

      expect(taken, isNot(contains(id)));
      expect(id.startsWith('custom-'), isTrue);
    });

    test('keeps drawing until the id is free', () {
      final random = _Sequence([1, 1, 2]);
      final taken = [
        newCustomThemeId(const [], random: _Sequence([1])),
      ];

      expect(newCustomThemeId(taken, random: random), isNot(taken.single));
    });
  });
}

class _Sequence implements Random {
  _Sequence(this.values);

  final List<int> values;
  int _next = 0;

  @override
  int nextInt(int max) => values[_next++ % values.length];

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}
