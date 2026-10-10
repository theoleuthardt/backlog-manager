import 'dart:math';

import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The WCAG contrast ratio of two colours.
double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (max(first, second) + 0.05) / (min(first, second) + 0.05);
}

void main() {
  test('contrast of black on white is 21', () {
    expect(
      contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.001),
    );
  });

  for (final theme in builtinThemes) {
    group('the ${theme.name} theme', () {
      final tokens = ShelfTokens.forTheme(resolveTheme(theme.id, const []));
      final texts = {
        'foreground': tokens.foreground,
        'text2': tokens.text2,
        'muted': tokens.muted,
        'faint': tokens.faint,
      };
      final grounds = {
        'background': tokens.background,
        'surface': tokens.surface,
        'surface2': tokens.surface2,
        'surface3': tokens.surface3,
      };

      for (final text in texts.entries) {
        for (final ground in grounds.entries) {
          test('${text.key} text on ${ground.key} has 4.5:1', () {
            expect(
              contrast(text.value, ground.value),
              greaterThanOrEqualTo(4.5),
            );
          });
        }
      }

      test('text on the accent colour has 4.5:1', () {
        expect(
          contrast(tokens.onAccent, tokens.accent),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('error text on a surface has 4.5:1', () {
        expect(
          contrast(tokens.danger, tokens.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('the accent stands out from the background with 3:1', () {
        expect(
          contrast(tokens.accent, tokens.background),
          greaterThanOrEqualTo(3),
        );
      });
    });
  }
}
