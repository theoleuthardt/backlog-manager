import 'dart:typed_data';

import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/cover_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

  group('the glow of a cover', () {
    Widget scene({Widget? backdrop}) => CoverGlowScope(
      child: SizedBox(
        width: 380,
        height: 600,
        child: Stack(
          children: [
            Positioned.fill(child: backdrop ?? const CoverGlowBackdrop()),
            const Positioned(
              left: 14,
              top: 14,
              width: 130,
              height: 195,
              child: CoverGlowHalo(child: SizedBox.expand()),
            ),
          ],
        ),
      ),
    );

    Alignment lightCenter(WidgetTester tester, String key) {
      final box = tester.widget<DecoratedBox>(find.byKey(Key(key)));
      final gradient = (box.decoration as BoxDecoration).gradient!;
      return (gradient as RadialGradient).center as Alignment;
    }

    Future<void> mount(
      WidgetTester tester, {
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: themed('shelfOled', scene(), width: 400),
        ),
      );
      await tester.pump();
    }

    testWidgets('lights the panel and the cover in the theme glow', (
      tester,
    ) async {
      await mount(tester);

      expect(find.byKey(const Key('cover-glow-veil')), findsOneWidget);
      expect(find.byKey(const Key('cover-glow-light-a')), findsOneWidget);
      expect(find.byKey(const Key('cover-glow-light-b')), findsOneWidget);
      final halo = tester.widget<DecoratedBox>(
        find.byKey(const Key('cover-glow-halo')),
      );
      final shadow = (halo.decoration as BoxDecoration).boxShadow!.single;
      expect(shadow.color.a, greaterThan(0));
    });

    group('with the motion on', () {
      late bool saved;

      setUp(() {
        saved = atmosphereMotion;
        atmosphereMotion = true;
      });
      tearDown(() => atmosphereMotion = saved);

      testWidgets('the lights drift across the panel', (tester) async {
        await mount(tester);
        final before = lightCenter(tester, 'cover-glow-light-a');

        await tester.pump(const Duration(seconds: 7));

        expect(
          lightCenter(tester, 'cover-glow-light-a'),
          isNot(equals(before)),
        );
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('they stand still when the setting is off', (tester) async {
        await mount(
          tester,
          overrides: [glowMotionProvider.overrideWith(_Off.new)],
        );
        final before = lightCenter(tester, 'cover-glow-light-a');

        await tester.pump(const Duration(seconds: 7));

        expect(lightCenter(tester, 'cover-glow-light-a'), equals(before));
      });
    });
  });
}

class _Off extends BackgroundMotionNotifier {
  _Off() : super(glowMotionStoreProvider);

  @override
  bool build() => false;
}
