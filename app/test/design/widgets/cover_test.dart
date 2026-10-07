import 'dart:convert';

import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

final pixel = MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ),
);

BoxDecoration fallbackOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(const Key('cover-fallback')),
  );
  return box.decoration as BoxDecoration;
}

void main() {
  final tokens = tokensOf('shelfOled');

  group('proxiedImageUrl', () {
    test('sends the address through the image proxy of the server', () {
      expect(
        proxiedImageUrl(
          'https://api.example.com',
          'https://images.igdb.com/a b.jpg',
        ),
        'https://api.example.com/api/images/proxy?url=https%3A%2F%2Fimages.igdb.com%2Fa+b.jpg',
      );
    });

    test('has no address for a missing or empty image', () {
      expect(proxiedImageUrl('https://api.example.com', null), isNull);
      expect(proxiedImageUrl('https://api.example.com', ''), isNull);
    });
  });

  group('ShelfCover', () {
    testWidgets('draws an overlay over the art', (tester) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 150,
          child: ShelfCover(title: 'Hades', overlay: Text('Overlay')),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('cover-art')),
          matching: find.text('Overlay'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is 2:3 with the card radius', (tester) async {
      await pumpThemed(tester, const ShelfCover(title: 'Hades'), width: 150);

      expect(
        tester.getSize(find.byKey(const Key('cover-art'))),
        const Size(150, 225),
      );
      final clip = tester.widget<ClipRRect>(
        find.byKey(const Key('cover-clip')),
      );
      expect(clip.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('prints the title bottom-left when there is no art', (
      tester,
    ) async {
      await pumpThemed(tester, const ShelfCover(title: 'Hades'), width: 150);

      expect(find.text('Hades'), findsOneWidget);
      final text = tester.widget<Text>(find.text('Hades'));
      expect(text.style!.fontSize, 15);
      expect(text.style!.fontWeight, FontWeight.w800);
      final cover = tester.getRect(find.byKey(const Key('cover-art')));
      expect(
        tester.getBottomLeft(find.text('Hades')).dy,
        greaterThan(cover.center.dy),
      );
      expect(
        tester.getTopLeft(find.text('Hades')).dx,
        lessThan(cover.center.dx),
      );
    });

    testWidgets(
      'gives a title always the same colours and other titles other ones',
      (tester) async {
        await pumpThemed(tester, const ShelfCover(title: 'Hades'), width: 150);
        final first = fallbackOf(tester).gradient! as LinearGradient;
        await pumpThemed(tester, const ShelfCover(title: 'Hades'), width: 150);
        final again = fallbackOf(tester).gradient! as LinearGradient;
        await pumpThemed(
          tester,
          const ShelfCover(title: 'Celeste'),
          width: 150,
        );
        final other = fallbackOf(tester).gradient! as LinearGradient;

        expect(again.colors, first.colors);
        expect(other.colors, isNot(first.colors));
      },
    );

    testWidgets('shows the picture instead of the title when there is art', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ShelfCover(title: 'Hades', image: pixel),
        width: 150,
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Hades'), findsNothing);
    });

    testWidgets('falls back to the title when the picture cannot be loaded', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ShelfCover(
          title: 'Hades',
          image: MemoryImage(utf8.encode('not an image')),
        ),
        width: 150,
      );
      await tester.pumpAndSettle();

      expect(find.text('Hades'), findsOneWidget);
    });

    testWidgets('casts a shadow in the glow colour', (tester) async {
      await pumpThemed(tester, const ShelfCover(title: 'Hades'), width: 150);

      final box = tester.widget<DecoratedBox>(
        find.byKey(const Key('cover-shadow')),
      );
      expect(
        (box.decoration as BoxDecoration).boxShadow,
        ShelfGlow.coverShadow(tokens),
      );
    });

    testWidgets('shows a thin progress bar and a meta line below', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const ShelfCover(title: 'Hades', progress: 0.4, meta: '41 of 60 h'),
        width: 150,
      );

      expect(find.byType(ShelfProgressBar), findsOneWidget);
      expect(tester.getSize(find.byType(ShelfProgressBar)).height, 3);
      expect(find.text('41 of 60 h'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ShelfProgressBar)).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('cover-art'))).dy,
        ),
      );
    });

    testWidgets('outlines a selected cover in the accent', (tester) async {
      await pumpThemed(
        tester,
        const ShelfCover(title: 'Hades', selected: true),
        width: 150,
      );

      final ring = tester.widget<DecoratedBox>(
        find.byKey(const Key('cover-ring')),
      );
      final border = (ring.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, tokens.accent);
      expect(border.top.width, 3);
    });

    testWidgets('clips the glow of the ring away from the cover below it', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const ShelfCover(title: 'Hades', selected: true),
        width: 150,
      );

      expect(find.byKey(const Key('cover-ring-clip')), findsOneWidget);
    });

    testWidgets('has no ring while it is not selected', (tester) async {
      await pumpThemed(tester, const ShelfCover(title: 'Hades'), width: 150);

      expect(find.byKey(const Key('cover-ring')), findsNothing);
    });

    testWidgets('shows a check circle in selection mode', (tester) async {
      await pumpThemed(
        tester,
        const ShelfCover(title: 'Hades', selectionMode: true),
        width: 150,
      );
      expect(
        tester.getSize(find.byKey(const Key('cover-check'))),
        const Size(22, 22),
      );
      expect(find.byIcon(Icons.check), findsNothing);

      await pumpThemed(
        tester,
        const ShelfCover(title: 'Hades', selectionMode: true, selected: true),
        width: 150,
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('has no check circle outside selection mode', (tester) async {
      await pumpThemed(tester, const ShelfCover(title: 'Hades'), width: 150);

      expect(find.byKey(const Key('cover-check')), findsNothing);
    });

    testWidgets('reports a tap and a right click', (tester) async {
      var taps = 0;
      var secondary = 0;
      await pumpThemed(
        tester,
        ShelfCover(
          title: 'Hades',
          onTap: () => taps++,
          onSecondaryTap: (_) => secondary++,
        ),
        width: 150,
      );

      await tester.tap(find.byKey(const Key('cover-art')));
      await tester.tap(
        find.byKey(const Key('cover-art')),
        buttons: kSecondaryButton,
      );

      expect(taps, 1);
      expect(secondary, 1);
    });
  });

  group('the cover grid', () {
    test('fits as many covers of at least 150 px as the width allows', () {
      expect(coverGridColumns(800), 4);
      expect(coverGridColumns(1000), 6);
      expect(coverGridColumns(150), 1);
      expect(coverGridColumns(100), 1);
    });

    test('stretches the covers to fill the row', () {
      expect(coverWidthFor(800, columns: 4), (800 - 3 * 16) / 4);
    });

    testWidgets('lays the covers out in rows of that many', (tester) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 800,
          height: 600,
          child: ShelfCoverGrid(
            itemCount: 9,
            itemBuilder: (context, index) => ShelfCover(title: 'Game $index'),
          ),
        ),
      );

      final firstRow = tester.getTopLeft(find.text('Game 0')).dy;
      expect(tester.getTopLeft(find.text('Game 3')).dy, firstRow);
      expect(tester.getTopLeft(find.text('Game 4')).dy, greaterThan(firstRow));
    });
  });

  group('the sliver grid', () {
    testWidgets(
      'lays the covers out like the grid and builds only the visible ones',
      (tester) async {
        await pumpThemed(
          tester,
          SizedBox(
            width: 800,
            height: 600,
            child: CustomScrollView(
              slivers: [
                ShelfCoverSliverGrid(
                  itemCount: 400,
                  itemBuilder: (context, index) =>
                      ShelfCover(title: 'Game $index'),
                ),
              ],
            ),
          ),
        );

        final firstRow = tester.getTopLeft(find.text('Game 0')).dy;
        expect(tester.getTopLeft(find.text('Game 3')).dy, firstRow);
        expect(
          tester.getTopLeft(find.text('Game 4')).dy,
          greaterThan(firstRow),
        );
        expect(find.byType(ShelfCover).evaluate().length, lessThan(40));
      },
    );
  });

  group('the shelf row', () {
    testWidgets('lines up 150 px wide covers and scrolls sideways', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 500,
          child: ShelfRow(
            itemCount: 8,
            itemBuilder: (context, index) => ShelfCover(title: 'Game $index'),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('cover-art')).first).width,
        150,
      );
      expect(find.text('Game 7'), findsNothing);

      await tester.drag(find.byType(ShelfRow), const Offset(-900, 0));
      await tester.pumpAndSettle();

      expect(find.text('Game 7'), findsOneWidget);
    });
  });

  goldenInBothThemes(
    'covers',
    () => Wrap(
      spacing: 16,
      runSpacing: 22,
      children: [
        const SizedBox(width: 120, child: ShelfCover(title: 'Hades')),
        const SizedBox(
          width: 120,
          child: ShelfCover(
            title: 'Celeste',
            progress: 0.4,
            meta: '41 of 60 h',
          ),
        ),
        const SizedBox(
          width: 120,
          child: ShelfCover(title: 'Disco Elysium', selected: true),
        ),
        const SizedBox(
          width: 120,
          child: ShelfCover(title: 'Stardew Valley', selectionMode: true),
        ),
        const SizedBox(
          width: 120,
          child: ShelfCover(
            title: 'Outer Wilds',
            selectionMode: true,
            selected: true,
          ),
        ),
      ],
    ),
    size: const Size(720, 360),
    width: 680,
  );
}
