import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  final tokens = tokensOf('shelfOled');

  group('ShelfSwitch', () {
    BoxDecoration track(WidgetTester tester) =>
        tester
                .widget<DecoratedBox>(find.byKey(const Key('switch-track')))
                .decoration
            as BoxDecoration;

    testWidgets('is a 38 x 22 pill', (tester) async {
      await pumpThemed(tester, ShelfSwitch(value: false, onChanged: (_) {}));

      expect(tester.getSize(find.byType(ShelfSwitch)), const Size(38, 22));
      expect(track(tester).borderRadius, BorderRadius.circular(11));
    });

    testWidgets('is on surface3 when off and accent with a glow when on', (
      tester,
    ) async {
      await pumpThemed(tester, ShelfSwitch(value: false, onChanged: (_) {}));
      expect(track(tester).color, tokens.surface3);
      expect(track(tester).boxShadow, isNull);

      await pumpThemed(tester, ShelfSwitch(value: true, onChanged: (_) {}));
      expect(track(tester).color, tokens.accent);
      expect(track(tester).boxShadow!.single.color, tokens.accentGlow);
    });

    testWidgets('moves the thumb to the right when on', (tester) async {
      await pumpThemed(tester, ShelfSwitch(value: false, onChanged: (_) {}));
      final off = tester.getCenter(find.byKey(const Key('switch-thumb'))).dx;

      await pumpThemed(tester, ShelfSwitch(value: true, onChanged: (_) {}));
      final on = tester.getCenter(find.byKey(const Key('switch-thumb'))).dx;

      expect(on, greaterThan(off));
    });

    testWidgets(
      'reports the opposite value when tapped or activated with Space',
      (tester) async {
        final values = <bool>[];
        await pumpThemed(
          tester,
          ShelfSwitch(value: false, onChanged: values.add),
        );

        await tester.tap(find.byType(ShelfSwitch));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);

        expect(values, [true, true]);
      },
    );

    testWidgets('is a toggled control for assistive technology', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        ShelfSwitch(value: true, onChanged: (_) {}, label: 'Owned'),
      );

      expect(
        tester.getSemantics(find.byType(ShelfSwitch)),
        isSemantics(hasToggledState: true, isToggled: true, label: 'Owned'),
      );
      handle.dispose();
    });
  });

  group('ShelfCheckbox', () {
    BoxDecoration box(WidgetTester tester) =>
        tester
                .widget<DecoratedBox>(find.byKey(const Key('checkbox-box')))
                .decoration
            as BoxDecoration;

    testWidgets('is an outlined 18 px box when unchecked', (tester) async {
      await pumpThemed(tester, ShelfCheckbox(value: false, onChanged: (_) {}));

      expect(tester.getSize(find.byType(ShelfCheckbox)), const Size(18, 18));
      expect(box(tester).color, isNull);
      expect((box(tester).border! as Border).top.color, tokens.borderStrong);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('is filled with the accent and shows a check when checked', (
      tester,
    ) async {
      await pumpThemed(tester, ShelfCheckbox(value: true, onChanged: (_) {}));

      expect(box(tester).color, tokens.accent);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows a dash when the state is mixed', (tester) async {
      await pumpThemed(tester, ShelfCheckbox(value: null, onChanged: (_) {}));

      expect(box(tester).color, tokens.accent);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('reports checked after a tap on an unchecked or mixed box', (
      tester,
    ) async {
      final values = <bool>[];
      await pumpThemed(
        tester,
        ShelfCheckbox(value: false, onChanged: values.add),
      );
      await tester.tap(find.byType(ShelfCheckbox));
      await pumpThemed(
        tester,
        ShelfCheckbox(value: null, onChanged: values.add),
      );
      await tester.tap(find.byType(ShelfCheckbox));
      await pumpThemed(
        tester,
        ShelfCheckbox(value: true, onChanged: values.add),
      );
      await tester.tap(find.byType(ShelfCheckbox));

      expect(values, [true, true, false]);
    });
  });

  group('ShelfProgressBar', () {
    testWidgets('fills the share of the track given by the value', (
      tester,
    ) async {
      await pumpThemed(tester, const ShelfProgressBar(value: 0.25), width: 200);

      expect(
        tester.getSize(find.byKey(const Key('progress-track'))),
        const Size(200, 6),
      );
      expect(tester.getSize(find.byKey(const Key('progress-fill'))).width, 50);
    });

    testWidgets('keeps the value between 0 and 1', (tester) async {
      await pumpThemed(tester, const ShelfProgressBar(value: 1.7), width: 200);
      expect(tester.getSize(find.byKey(const Key('progress-fill'))).width, 200);

      await pumpThemed(tester, const ShelfProgressBar(value: -1), width: 200);
      expect(find.byKey(const Key('progress-fill')), findsNothing);
    });

    testWidgets('uses the glowing accent gradient for the fill', (
      tester,
    ) async {
      await pumpThemed(tester, const ShelfProgressBar(value: 0.5), width: 200);

      final fill = tester.widget<DecoratedBox>(
        find.byKey(const Key('progress-fill')),
      );
      final decoration = fill.decoration as BoxDecoration;
      expect((decoration.gradient! as LinearGradient).colors, [
        tokens.accentA,
        tokens.accentB,
      ]);
    });
  });

  group('InterestSegments', () {
    Color segment(WidgetTester tester, int index) {
      final box = tester.widget<DecoratedBox>(
        find.byKey(Key('interest-$index')),
      );
      return (box.decoration as BoxDecoration).color!;
    }

    testWidgets('fills as many of the ten segments as the value', (
      tester,
    ) async {
      await pumpThemed(tester, InterestSegments(value: 4, onChanged: (_) {}));

      expect(find.byType(InterestSegments), findsOneWidget);
      for (var n = 1; n <= 10; n++) {
        expect(
          segment(tester, n),
          n <= 4 ? tokens.accent : tokens.surface3,
          reason: '$n',
        );
      }
    });

    testWidgets(
      'sets the value to the tapped segment and clears on a second tap',
      (tester) async {
        final values = <int>[];
        await pumpThemed(
          tester,
          InterestSegments(value: 3, onChanged: values.add),
        );

        await tester.tap(find.byKey(const Key('interest-7')));
        await tester.tap(find.byKey(const Key('interest-3')));

        expect(values, [7, 0]);
      },
    );

    testWidgets('is read-only without onChanged', (tester) async {
      await pumpThemed(tester, const InterestSegments(value: 3));

      await tester.tap(find.byKey(const Key('interest-7')));
      expect(tester.takeException(), isNull);
    });
  });

  group('StarRating', () {
    testWidgets('shows ten stars and fills as many as the value', (
      tester,
    ) async {
      await pumpThemed(tester, StarRating(value: 7, onChanged: (_) {}));

      expect(find.byIcon(Icons.star), findsNWidgets(7));
      expect(find.byIcon(Icons.star_border), findsNWidgets(3));
    });

    testWidgets(
      'sets the value to the tapped star and clears on a second tap',
      (tester) async {
        final values = <int>[];
        await pumpThemed(tester, StarRating(value: 4, onChanged: values.add));

        await tester.tap(find.byKey(const Key('star-8')));
        await tester.tap(find.byKey(const Key('star-4')));

        expect(values, [8, 0]);
      },
    );

    testWidgets('exposes the value to assistive technology', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, StarRating(value: 7, onChanged: (_) {}));

      expect(
        tester.getSemantics(find.byType(StarRating)),
        isSemantics(label: 'Review: 7 of 10 stars'),
      );
      handle.dispose();
    });
  });

  goldenInBothThemes(
    'toggles_progress',
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShelfSwitch(value: false, onChanged: (_) {}),
            const SizedBox(width: 12),
            ShelfSwitch(value: true, onChanged: (_) {}),
            const SizedBox(width: 24),
            ShelfCheckbox(value: false, onChanged: (_) {}),
            const SizedBox(width: 8),
            ShelfCheckbox(value: true, onChanged: (_) {}),
            const SizedBox(width: 8),
            ShelfCheckbox(value: null, onChanged: (_) {}),
          ],
        ),
        const SizedBox(height: 18),
        const ShelfProgressBar(value: 0.62),
        const SizedBox(height: 18),
        InterestSegments(value: 6, onChanged: (_) {}),
        const SizedBox(height: 14),
        StarRating(value: 7, onChanged: (_) {}),
      ],
    ),
    size: const Size(380, 220),
    width: 340,
  );
}
