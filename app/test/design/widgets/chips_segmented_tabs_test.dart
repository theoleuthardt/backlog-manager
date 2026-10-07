import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/segmented.dart';
import 'package:backlog_manager/design/widgets/tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

BoxDecoration chipDecoration(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(const Key('chip-surface')),
  );
  return box.decoration as BoxDecoration;
}

Color chipTextColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

void main() {
  final tokens = tokensOf('shelfOled');

  group('ShelfChip', () {
    testWidgets('is a 24 px pill', (tester) async {
      await pumpThemed(tester, const ShelfChip(label: 'RPG'));

      expect(tester.getSize(find.byType(ShelfChip)).height, 24);
      expect(chipDecoration(tester).borderRadius, BorderRadius.circular(999));
    });

    testWidgets('writes neutral on surface2 with a subtle border', (
      tester,
    ) async {
      await pumpThemed(tester, const ShelfChip(label: 'RPG'));

      expect(chipDecoration(tester).color, tokens.surface2);
      expect(
        (chipDecoration(tester).border! as Border).top.color,
        tokens.borderSubtle,
      );
      expect(chipTextColor(tester, 'RPG'), tokens.text2);
    });

    testWidgets('fills an active chip with the foreground', (tester) async {
      await pumpThemed(
        tester,
        const ShelfChip(label: 'All', kind: ShelfChipKind.active),
      );

      expect(chipDecoration(tester).color, tokens.foreground);
      expect(chipTextColor(tester, 'All'), tokens.background);
    });

    testWidgets('tints accent, info and ok chips', (tester) async {
      await pumpThemed(
        tester,
        const ShelfChip(label: 'New', kind: ShelfChipKind.accent),
      );
      expect(chipDecoration(tester).color, tokens.accentSoft);
      expect(chipTextColor(tester, 'New'), tokens.accent);

      await pumpThemed(
        tester,
        const ShelfChip(label: 'Found', kind: ShelfChipKind.info),
      );
      expect(chipDecoration(tester).color, atOpacity(tokens.info, 0.14));
      expect(chipTextColor(tester, 'Found'), tokens.info);

      await pumpThemed(
        tester,
        const ShelfChip(label: 'Imported', kind: ShelfChipKind.ok),
      );
      expect(chipDecoration(tester).color, atOpacity(tokens.success, 0.14));
      expect(chipTextColor(tester, 'Imported'), tokens.success);
    });

    testWidgets('draws the add chip with a dashed border', (tester) async {
      await pumpThemed(
        tester,
        const ShelfChip(label: 'Add filter', kind: ShelfChipKind.add),
      );

      expect(find.byKey(const Key('chip-dashed-border')), findsOneWidget);
      expect(chipTextColor(tester, 'Add filter'), tokens.muted);
    });

    testWidgets('calls onPressed and onRemove', (tester) async {
      var pressed = 0;
      var removed = 0;
      await pumpThemed(
        tester,
        ShelfChip(
          label: 'Genre',
          onPressed: () => pressed++,
          onRemove: () => removed++,
        ),
      );

      await tester.tap(find.text('Genre'));
      await tester.tap(find.byKey(const Key('chip-remove')));

      expect(pressed, 1);
      expect(removed, 1);
    });

    testWidgets('labels the remove button for assistive technology', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        ShelfChip(label: 'Genre', onPressed: () {}, onRemove: () {}),
      );

      expect(find.bySemanticsLabel('Remove Genre'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ShelfSegmented', () {
    Widget segmented({int value = 1, ValueChanged<int>? onChanged}) {
      return ShelfSegmented<int>(
        value: value,
        onChanged: onChanged ?? (_) {},
        segments: const [
          ShelfSegment(value: 0, label: 'Library'),
          ShelfSegment(value: 1, label: 'Wishlist'),
          ShelfSegment(value: 2, label: 'Playtimes'),
        ],
      );
    }

    testWidgets('puts the track on surface2 with the control radius', (
      tester,
    ) async {
      await pumpThemed(tester, segmented());

      final track = tester.widget<DecoratedBox>(
        find.byKey(const Key('segmented-track')),
      );
      final decoration = track.decoration as BoxDecoration;
      expect(decoration.color, tokens.surface2);
      expect(decoration.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('raises the selected segment onto surface3', (tester) async {
      await pumpThemed(tester, segmented(value: 1));

      BoxDecoration segment(int value) =>
          tester
                  .widget<DecoratedBox>(
                    find.byKey(Key('segment-$value-surface')),
                  )
                  .decoration
              as BoxDecoration;

      expect(segment(1).color, tokens.surface3);
      expect(segment(1).boxShadow, isNotEmpty);
      expect(segment(0).color, isNull);
    });

    testWidgets('reports the tapped segment', (tester) async {
      int? changed;
      await pumpThemed(
        tester,
        segmented(onChanged: (value) => changed = value),
      );

      await tester.tap(find.text('Playtimes'));

      expect(changed, 2);
    });

    testWidgets('marks the selected segment for assistive technology', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, segmented(value: 1));

      expect(
        tester.getSemantics(find.byKey(const Key('segment-1'))),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('segment-0'))),
        isNot(isSemantics(isSelected: true)),
      );
      handle.dispose();
    });
  });

  group('ShelfTabs', () {
    testWidgets('underlines the active tab in the accent', (tester) async {
      await pumpThemed(
        tester,
        ShelfTabs(
          labels: const ['Overview', 'Progress', 'Review'],
          index: 1,
          onChanged: (_) {},
        ),
      );

      final underline = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const Key('tab-1')),
          matching: find.byKey(const Key('tab-underline')),
        ),
      );
      expect(underline.color, tokens.accent);
      expect(
        tester.getSize(find.byKey(const Key('tab-underline')).first).height,
        2,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('tab-0')),
          matching: find.byKey(const Key('tab-underline')),
        ),
        findsNothing,
      );
      expect(chipTextColor(tester, 'Progress'), tokens.foreground);
      expect(chipTextColor(tester, 'Overview'), tokens.muted);
    });

    testWidgets('reports the tapped tab', (tester) async {
      int? changed;
      await pumpThemed(
        tester,
        ShelfTabs(
          labels: const ['Overview', 'Progress'],
          index: 0,
          onChanged: (index) => changed = index,
        ),
      );

      await tester.tap(find.text('Progress'));

      expect(changed, 1);
    });
  });

  goldenInBothThemes(
    'chips_segmented_tabs',
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const ShelfChip(label: 'Neutral'),
            const ShelfChip(label: 'Active', kind: ShelfChipKind.active),
            const ShelfChip(label: 'Accent', kind: ShelfChipKind.accent),
            const ShelfChip(label: 'Info', kind: ShelfChipKind.info),
            const ShelfChip(label: 'Ok', kind: ShelfChipKind.ok),
            ShelfChip(label: 'Genre: RPG', onRemove: () {}),
            const ShelfChip(label: 'Add filter', kind: ShelfChipKind.add),
          ],
        ),
        const SizedBox(height: 16),
        ShelfSegmented<int>(
          value: 1,
          onChanged: (_) {},
          segments: const [
            ShelfSegment(value: 0, label: 'Library'),
            ShelfSegment(value: 1, label: 'Wishlist'),
            ShelfSegment(value: 2, label: 'Playtimes'),
          ],
        ),
        const SizedBox(height: 16),
        ShelfTabs(
          labels: const ['Overview', 'Progress', 'Review', 'Trailer'],
          index: 1,
          onChanged: (_) {},
        ),
      ],
    ),
    size: const Size(520, 220),
    width: 480,
  );
}
