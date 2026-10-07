import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfTokens tokensOf(String id) => ShelfTokens.forTheme(resolveTheme(id, []));

ThemeData themeOf(String id) => buildShelfTheme(tokensOf(id));

void main() {
  group('buildShelfTheme', () {
    test('carries the tokens as a theme extension', () {
      final theme = themeOf('shelfOled');

      expect(theme.extension<ShelfTokens>(), tokensOf('shelfOled'));
      expect(theme.extension<ShelfTextStyles>(), isNotNull);
    });

    test('is dark for dark themes and light for the light theme', () {
      expect(themeOf('shelfOled').brightness, Brightness.dark);
      expect(themeOf('freaky').brightness, Brightness.dark);
      expect(themeOf('light').brightness, Brightness.light);
    });

    test('maps the tokens onto the colour scheme', () {
      final tokens = tokensOf('shelfOled');
      final scheme = themeOf('shelfOled').colorScheme;

      expect(scheme.primary, tokens.accent);
      expect(scheme.onPrimary, tokens.onAccent);
      expect(scheme.surface, tokens.surface);
      expect(scheme.onSurface, tokens.foreground);
      expect(scheme.error, tokens.danger);
      expect(scheme.outline, tokens.borderStrong);
      expect(scheme.outlineVariant, tokens.borderSubtle);
    });

    test('keeps text on secondary and error at 4.5:1 in every built-in', () {
      for (final theme in builtinThemes) {
        final scheme = themeOf(theme.id).colorScheme;

        expect(
          contrastRatio(scheme.onSecondary, scheme.secondary),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.id} onSecondary',
        );
        expect(
          contrastRatio(scheme.onError, scheme.error),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.id} onError',
        );
      }
    });

    test('uses the window background for scaffolds', () {
      expect(
        themeOf('light').scaffoldBackgroundColor,
        tokensOf('light').background,
      );
    });

    test('is compact', () {
      expect(themeOf('shelfOled').visualDensity, VisualDensity.compact);
    });
  });

  group('typography', () {
    final theme = themeOf('shelfOled');

    test('uses Plus Jakarta Sans at the sizes of the design', () {
      final body = theme.textTheme.bodyMedium!;

      expect(body.fontFamily, 'PlusJakartaSans');
      expect(body.fontSize, 14);
      expect(body.height, 1.4);
      expect(body.fontWeight, FontWeight.w400);
    });

    test('maps the scale onto the text theme roles', () {
      final text = theme.textTheme;

      expect(text.displayMedium!.fontSize, 30);
      expect(text.displayMedium!.fontWeight, FontWeight.w800);
      expect(text.headlineMedium!.fontSize, 26);
      expect(text.titleMedium!.fontSize, 16);
      expect(text.titleSmall!.fontSize, 13);
      expect(text.labelLarge!.fontSize, 13);
      expect(text.labelLarge!.fontWeight, FontWeight.w600);
      expect(text.labelMedium!.fontSize, 12);
      expect(text.bodySmall!.fontSize, 12.5);
    });

    test('has the styles that no text theme role fits', () {
      final styles = theme.extension<ShelfTextStyles>()!;
      final tokens = tokensOf('shelfOled');

      expect(styles.eyebrow.fontSize, 11);
      expect(styles.eyebrow.fontWeight, FontWeight.w700);
      expect(styles.eyebrow.letterSpacing, closeTo(11 * 0.12, 0.001));
      expect(styles.eyebrow.color, tokens.accent);
      expect(styles.sidebarLabel.letterSpacing, closeTo(11 * 0.08, 0.001));
      expect(styles.sidebarLabel.color, tokens.faint);
      expect(styles.coverTitle.fontSize, 15);
      expect(styles.coverTitle.height, 1.1);
      expect(styles.page.letterSpacing, closeTo(26 * -0.02, 0.001));
    });

    test('colours the scale with the tokens', () {
      final tokens = tokensOf('light');
      final styles = themeOf('light').extension<ShelfTextStyles>()!;

      expect(styles.body.color, tokens.foreground);
      expect(styles.caption.color, tokens.muted);
    });
  });

  group('bundled font', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      test('ships Plus Jakarta Sans $weight with the app', () async {
        final data = await rootBundle.load(
          'assets/fonts/PlusJakartaSans-$weight.ttf',
        );

        expect(data.lengthInBytes, greaterThan(50000));
      });
    }
  });

  group('component themes', () {
    final theme = themeOf('shelfOled');
    final tokens = tokensOf('shelfOled');

    test('filled buttons are accent filled with the control radius', () {
      final style = theme.filledButtonTheme.style!;

      expect(style.backgroundColor!.resolve({}), tokens.accent);
      expect(style.foregroundColor!.resolve({}), tokens.onAccent);
      expect(style.minimumSize!.resolve({})!.height, 32);
      expect(
        (style.shape!.resolve({}) as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(8),
      );
    });

    test('inputs are 34 high with the control radius and a glow focus', () {
      final decoration = theme.inputDecorationTheme;
      final focused = decoration.focusedBorder! as OutlineInputBorder;

      expect(decoration.constraints!.minHeight, 34);
      expect(focused.borderRadius, BorderRadius.circular(8));
      expect(focused.borderSide.color, tokens.glow);
    });

    test('dialogs use the dialog radius on the surface', () {
      final dialog = theme.dialogTheme;

      expect(dialog.backgroundColor, tokens.surface);
      expect(
        (dialog.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(16),
      );
    });

    test('a switch that is on uses the accent', () {
      final thumb = theme.switchTheme.trackColor!.resolve({
        WidgetState.selected,
      });

      expect(thumb, tokens.accent);
    });

    test('the selected tab is underlined in the accent', () {
      expect(theme.tabBarTheme.indicatorColor, tokens.accent);
      expect(theme.tabBarTheme.labelColor, tokens.foreground);
    });
  });

  group('switching the theme at runtime', () {
    Widget app(String themeId) {
      return MaterialApp(
        theme: themeOf(themeId),
        home: Builder(
          builder: (context) {
            final tokens = Theme.of(context).extension<ShelfTokens>()!;
            return Scaffold(
              body: Container(
                key: const Key('sample'),
                color: tokens.surface,
                child: Text('Hades', style: TextStyle(color: tokens.accent)),
              ),
            );
          },
        ),
      );
    }

    Color sampleColor(WidgetTester tester) {
      final box = tester.widget<Container>(find.byKey(const Key('sample')));
      return box.color!;
    }

    testWidgets('repaints a sample widget tree', (tester) async {
      await tester.pumpWidget(app('shelfOled'));
      expect(sampleColor(tester), tokensOf('shelfOled').surface);

      await tester.pumpWidget(app('light'));
      await tester.pumpAndSettle();

      expect(sampleColor(tester), tokensOf('light').surface);
      expect(
        tester.widget<Text>(find.text('Hades')).style!.color,
        tokensOf('light').accent,
      );
    });
  });
}
