import 'dart:math';

import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/freaky_orbs.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfTokens tokensOf(String id) => ShelfTokens.forTheme(resolveTheme(id, []));

Widget host(
  String themeId,
  Size size, {
  Widget? child,
  bool? orbs,
  bool freakyActive = false,
  bool reduceMotion = false,
}) {
  return ProviderScope(
    overrides: [
      themeIdProvider.overrideWith(
        () => _FixedTheme(freakyActive ? 'freaky' : 'shelfOled'),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildShelfTheme(tokensOf(themeId)),
      builder: (context, home) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: home!,
      ),
      home: Center(
        child: SizedBox.fromSize(
          size: size,
          child: AtmosphereBackground(
            orbs: orbs,
            child: child ?? const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

class _FixedTheme extends ThemeIdNotifier {
  _FixedTheme(this.id);

  final String id;

  @override
  String build() => id;
}

void main() {
  group('atmosphereStars', () {
    final tokens = tokensOf('shelfOled');

    test('repeats each tile across the window', () {
      final stars = atmosphereStars(const Size(1440, 900), tokens);
      final gold = stars.where((s) => s.color == tokens.starGold).toList();

      expect(gold.map((s) => s.center), [
        for (var y = 0; y < 2; y++)
          for (var x = 0; x < 3; x++) Offset(130 + x * 520, 200 + y * 420),
      ]);
    });

    test('puts a star of every layer at its documented offset', () {
      final centers = atmosphereStars(
        const Size(1440, 900),
        tokens,
      ).map((s) => s.center).toSet();

      expect(
        centers,
        containsAll(const [
          Offset(12, 22),
          Offset(70, 84),
          Offset(96, 30),
          Offset(40, 118),
          Offset(150, 60),
          Offset(210, 150),
          Offset(58, 44),
          Offset(130, 200),
        ]),
      );
    });

    test('colours the small stars with the three star colours', () {
      final stars = atmosphereStars(const Size(1440, 900), tokens);

      expect(
        stars.firstWhere((s) => s.center == const Offset(12, 22)).color,
        tokens.starA,
      );
      expect(
        stars.firstWhere((s) => s.center == const Offset(70, 84)).color,
        tokens.starB,
      );
      expect(
        stars.firstWhere((s) => s.center == const Offset(96, 30)).color,
        tokens.starC,
      );
    });

    test('gives only the bright and gold stars a halo', () {
      final stars = atmosphereStars(const Size(1440, 900), tokens);

      expect(
        stars
            .where((s) => s.color == tokens.starGold)
            .every((s) => s.halo == 9),
        isTrue,
      );
      expect(
        stars
            .where((s) => s.color == tokens.starHot)
            .map((s) => s.halo)
            .toSet(),
        {7.0, 8.0},
      );
      expect(
        stars.where((s) => s.color == tokens.starA).every((s) => s.halo == 0),
        isTrue,
      );
    });

    test('only places stars inside the window', () {
      const size = Size(500, 300);

      for (final star in atmosphereStars(size, tokens)) {
        expect(star.center.dx, lessThan(size.width));
        expect(star.center.dy, lessThan(size.height));
      }
    });

    test(
      'is the same for the same input and takes its colours from the tokens',
      () {
        final first = atmosphereStars(const Size(800, 600), tokens);
        final second = atmosphereStars(const Size(800, 600), tokens);
        final light = atmosphereStars(const Size(800, 600), tokensOf('light'));

        expect(first.map((s) => s.center), second.map((s) => s.center));
        expect(light.first.color, isNot(first.first.color));
      },
    );

    test('has no stars in a window of no size', () {
      expect(atmosphereStars(Size.zero, tokens), isEmpty);
    });
  });

  group('AtmospherePainter', () {
    test('repaints for other tokens but not for the same ones', () {
      final painter = AtmospherePainter(tokensOf('shelfOled'));

      expect(
        painter.shouldRepaint(AtmospherePainter(tokensOf('shelfOled'))),
        false,
      );
      expect(painter.shouldRepaint(AtmospherePainter(tokensOf('light'))), true);
    });
  });

  group('AtmosphereBackground', () {
    testWidgets('shows its child above the painted sky', (tester) async {
      await tester.pumpWidget(
        host('shelfOled', const Size(800, 500), child: const Text('Shelf')),
      );

      expect(find.text('Shelf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('paints again at another size', (tester) async {
      await tester.pumpWidget(host('freaky', const Size(1440, 900)));
      await tester.pumpWidget(host('freaky', const Size(640, 400)));

      expect(tester.takeException(), isNull);
    });
  });

  group('goldens of the background', () {
    for (final id in ['shelfOled', 'light', 'colorful', 'freaky']) {
      testWidgets('is drawn in $id', tags: 'golden', (tester) async {
        tester.view.physicalSize = const Size(960, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(host(id, const Size(960, 600)));

        await expectLater(
          find.byType(AtmosphereBackground),
          matchesGoldenFile('goldens/atmosphere_$id.png'),
        );
      });
    }
  });

  group('the orbs of the Freaky theme', () {
    testWidgets('show for the Freaky theme', (tester) async {
      await tester.pumpWidget(
        host('freaky', const Size(400, 300), freakyActive: true),
      );

      expect(find.byKey(const Key('freaky-orbs')), findsOneWidget);
    });

    testWidgets('do not show for another theme', (tester) async {
      await tester.pumpWidget(host('shelfOled', const Size(400, 300)));

      expect(find.byKey(const Key('freaky-orbs')), findsNothing);
    });

    testWidgets('are off when the system asks for less motion', (tester) async {
      await tester.pumpWidget(
        host(
          'freaky',
          const Size(400, 300),
          freakyActive: true,
          reduceMotion: true,
        ),
      );

      expect(find.byKey(const Key('freaky-orbs')), findsNothing);
    });

    testWidgets('can be forced on or off by the caller', (tester) async {
      await tester.pumpWidget(
        host('shelfOled', const Size(400, 300), orbs: true),
      );
      expect(find.byKey(const Key('freaky-orbs')), findsOneWidget);

      await tester.pumpWidget(
        host('freaky', const Size(400, 300), freakyActive: true, orbs: false),
      );
      expect(find.byKey(const Key('freaky-orbs')), findsNothing);
    });

    testWidgets('keep moving frame after frame without taking part in input', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          'freaky',
          const Size(400, 300),
          freakyActive: true,
          child: const SizedBox.expand(key: Key('content')),
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('content')), findsOneWidget);
    });

    testWidgets('golden: the orbs over the Freaky atmosphere', tags: 'golden', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildShelfTheme(tokensOf('freaky')),
          home: SizedBox(
            width: 600,
            height: 400,
            child: Stack(
              children: [
                const ColoredBox(
                  color: Color(0xFF04040E),
                  child: SizedBox.expand(),
                ),
                FreakyOrbs(random: Random(3)),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/freaky_orbs.png'),
      );
    });
  });
}
