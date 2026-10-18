import 'dart:math';
import 'dart:ui' as ui;

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

    test('are laid out the same way every time', () {
      final first = atmosphereStars(const Size(1440, 900), tokens);
      final second = atmosphereStars(const Size(1440, 900), tokens);

      expect(
        [for (final star in first) star.center],
        [for (final star in second) star.center],
      );
    });

    test('are scattered at random, not in a grid', () {
      final stars = atmosphereStars(const Size(1440, 900), tokens);
      final columns = {for (final star in stars) (star.center.dx / 10).round()};
      final rows = {for (final star in stars) (star.center.dy / 10).round()};

      expect(stars.length, greaterThan(300));
      expect(columns.length, greaterThan(100));
      expect(rows.length, greaterThan(60));
    });

    test('keep their place when the window grows', () {
      final small = atmosphereStars(const Size(800, 600), tokens);
      final large = atmosphereStars(const Size(1440, 900), tokens);
      final largeCenters = {for (final star in large) star.center};

      expect(large.length, greaterThan(small.length));
      expect(small.every((star) => largeCenters.contains(star.center)), isTrue);
    });

    test('only places stars inside the window', () {
      for (final star in atmosphereStars(const Size(300, 200), tokens)) {
        expect(star.center.dx, lessThan(300 + 12));
        expect(star.center.dy, lessThan(200 + 12));
      }
    });

    test('colours the small stars with the three star colours', () {
      final small = atmosphereStars(
        const Size(1440, 900),
        tokens,
      ).where((star) => star.halo == 0).map((star) => star.color).toSet();

      expect(small, {tokens.starA, tokens.starB, tokens.starC});
    });

    test('have bright stars with a halo and gold ones', () {
      final stars = atmosphereStars(const Size(1440, 900), tokens);
      final bright = stars.where((star) => star.halo > 0);

      expect(bright.any((star) => star.color == tokens.starHot), isTrue);
      expect(bright.any((star) => star.color == tokens.starGold), isTrue);
      expect(bright.every((star) => star.haloColor.a > 0), isTrue);
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

    testWidgets('keeps every nebula inside its ellipse', (tester) async {
      final tokens = tokensOf('shelfOled');
      const size = Size(2400, 1200);
      final image = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        AtmospherePainter(tokens).paint(Canvas(recorder), size);
        final picture = recorder.endRecording();
        addTearDown(picture.dispose);
        return picture.toImage(2400, 1200);
      });
      addTearDown(image!.dispose);
      final bytes = (await tester.runAsync(image.toByteData))!;

      const cornerOfBox = Offset(2278, 986);
      var strongest = 0;
      for (var dx = 0; dx < 6; dx++) {
        for (var dy = 0; dy < 6; dy++) {
          final at =
              ((cornerOfBox.dy.toInt() + dy) * 2400 +
                  cornerOfBox.dx.toInt() +
                  dx) *
              4;
          final blue = bytes.getUint8(at + 2);
          strongest = max(
            strongest,
            blue - (tokens.background.b * 255).round(),
          );
        }
      }

      expect(strongest, lessThan(24));
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

    testWidgets('keep moving frame after frame', (tester) async {
      await tester.pumpWidget(
        host('freaky', const Size(400, 300), freakyActive: true),
      );

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.takeException(), isNull);
    });

    testWidgets('let taps through to what is above them', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          'freaky',
          const Size(400, 300),
          freakyActive: true,
          child: GestureDetector(
            key: const Key('content'),
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('content')));

      expect(taps, 1);
    });

    testWidgets('the orbs repaint at most 30 times per second', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildShelfTheme(tokensOf('freaky')),
          home: SizedBox(
            width: 600,
            height: 400,
            child: FreakyOrbs(random: Random(3)),
          ),
        ),
      );
      final painter = tester
          .widget<CustomPaint>(find.byKey(const Key('freaky-orbs')))
          .painter!;
      var repaints = 0;
      void count() => repaints++;
      painter.addListener(count);

      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(microseconds: 16667));
      }

      painter.removeListener(count);
      expect(repaints, inInclusiveRange(25, 31));
      await tester.pumpWidget(const SizedBox());
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
