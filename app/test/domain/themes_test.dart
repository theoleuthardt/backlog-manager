import 'dart:convert';
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
  appearanceTests();
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

    test(
      'ships shelfOled, dark, light, colorful and freaky as built-in themes',
      () {
        expect(builtinThemes.map((theme) => theme.id), [
          'shelfOled',
          'dark',
          'light',
          'colorful',
          'freaky',
        ]);
      },
    );
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

const neonJson = {
  'id': 'custom-neon',
  'name': 'Neon',
  'background': '#0a0014',
  'surface': '#1a0033',
  'foreground': '#f5e9ff',
  'accent': '#ff2bd6',
  'border': '#5b2a86',
  'glow': '#00e5ff',
};

void appearanceTests() {
  group('the built-in themes', () {
    test('the old dark theme keeps its id and is called Classic dark', () {
      final dark = builtinThemes.firstWhere((theme) => theme.id == 'dark');

      expect(dark.name, 'Classic dark');
    });

    test('are listed with Classic dark last', () {
      expect(displayThemes.map((theme) => theme.id), [
        'shelfOled',
        'light',
        'colorful',
        'freaky',
        'dark',
      ]);
    });
  });

  group('ThemeColors', () {
    const colors = ThemeColors(
      background: '#000000',
      surface: '#0b0b0e',
      foreground: '#f2f2f3',
      accent: '#f5a524',
      border: '#353a4c',
      glow: '#3b82f6',
    );

    test('are equal when every colour is', () {
      expect(colors, colors.withColor(ThemeColorField.accent, '#f5a524'));
      expect(
        colors == colors.withColor(ThemeColorField.accent, '#000001'),
        isFalse,
      );
    });

    test('read and change one colour by its field', () {
      final changed = colors.withColor(ThemeColorField.glow, '#ffffff');

      expect(changed.colorOf(ThemeColorField.glow), '#ffffff');
      expect(changed.colorOf(ThemeColorField.accent), '#f5a524');
    });

    test('are valid when all six are hex colours', () {
      expect(colors.isValid, isTrue);
      expect(colors.withColor(ThemeColorField.border, '#12').isValid, isFalse);
    });

    test('every field has a label and a hint', () {
      expect(ThemeColorField.values.map((field) => field.label), [
        'Background',
        'Surface',
        'Text',
        'Accent',
        'Border',
        'Glow',
      ]);
      expect(ThemeColorField.background.hint, 'Page background');
      expect(ThemeColorField.surface.hint, 'Cards, dialogs and menus');
    });
  });

  group('CustomTheme json', () {
    test('reads the flat shape the backend stores', () {
      final theme = CustomTheme.fromJson(neonJson);

      expect(theme.id, 'custom-neon');
      expect(theme.name, 'Neon');
      expect(theme.colors.accent, '#ff2bd6');
      expect(theme.colors.glow, '#00e5ff');
    });

    test('writes the same shape back', () {
      expect(CustomTheme.fromJson(neonJson).toJson(), neonJson);
    });
  });

  group('canSaveTheme', () {
    final colors = CustomTheme.fromJson(neonJson).colors;

    test('needs a name and six valid colours', () {
      expect(
        canSaveTheme(
          name: 'Neon',
          colors: colors,
          customCount: 0,
          editing: false,
        ),
        isTrue,
      );
      expect(
        canSaveTheme(
          name: '  ',
          colors: colors,
          customCount: 0,
          editing: false,
        ),
        isFalse,
      );
      expect(
        canSaveTheme(
          name: 'x',
          colors: colors.withColor(ThemeColorField.accent, 'red'),
          customCount: 0,
          editing: false,
        ),
        isFalse,
      );
    });

    test('a new theme is refused at the limit, an edit is not', () {
      expect(
        canSaveTheme(
          name: 'x',
          colors: colors,
          customCount: maxCustomThemes,
          editing: false,
        ),
        isFalse,
      );
      expect(
        canSaveTheme(
          name: 'x',
          colors: colors,
          customCount: maxCustomThemes,
          editing: true,
        ),
        isTrue,
      );
    });

    test('the limit message names the number', () {
      expect(
        themeLimitMessage,
        'You can keep up to 10 custom themes - delete one to save another.',
      );
    });

    test('the toasts name the theme', () {
      expect(themeSavedMessage('Neon'), 'Theme "Neon" saved');
      expect(themeDeletedMessage('Neon'), 'Theme "Neon" deleted');
    });
  });

  group('the local cache', () {
    test('keeps the selection and the custom themes', () {
      final text = encodeThemeCache('custom-neon', [
        CustomTheme.fromJson(neonJson),
      ]);

      final decoded = decodeThemeCache(text)!;
      expect(decoded.id, 'custom-neon');
      expect(decoded.customThemes.single.name, 'Neon');
    });

    test('reads what the web client wrote', () {
      final decoded = decodeThemeCache(
        jsonEncode({
          'id': 'custom-neon',
          'customThemes': [neonJson],
          'dataTheme': 'custom',
          'colorScheme': 'dark',
          'variables': {'--t-background': '#0a0014'},
        }),
      )!;

      expect(decoded.id, 'custom-neon');
      expect(decoded.customThemes, hasLength(1));
    });

    test('is nothing for text that is not a selection', () {
      expect(decodeThemeCache(null), isNull);
      expect(decodeThemeCache('not json'), isNull);
      expect(decodeThemeCache('[]'), isNull);
      expect(decodeThemeCache(jsonEncode({'id': 3})), isNull);
    });

    test('drops stored themes that are not valid', () {
      final decoded = decodeThemeCache(
        jsonEncode({
          'id': 'light',
          'customThemes': [
            neonJson,
            {'id': 'broken'},
          ],
        }),
      )!;

      expect(decoded.customThemes.map((theme) => theme.id), ['custom-neon']);
    });
  });
}
