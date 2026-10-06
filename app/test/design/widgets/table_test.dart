import 'package:backlog_manager/design/widgets/table.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

class Game {
  const Game(this.title, this.hours);

  final String title;
  final int hours;
}

const games = [Game('Hades', 41), Game('Celeste', 8), Game('Outer Wilds', 22)];

List<ShelfColumn<Game>> columns() => [
  ShelfColumn(
    header: 'Title',
    flex: 3,
    cell: (context, game) => Text(game.title),
  ),
  ShelfColumn(
    header: 'Hours',
    cell: (context, game) => Text('${game.hours} h'),
  ),
];

BoxDecoration rowDecoration(WidgetTester tester, int index) {
  final box = tester.widget<DecoratedBox>(find.byKey(Key('table-row-$index')));
  return box.decoration as BoxDecoration;
}

void main() {
  final tokens = tokensOf('shelfOled');

  group('ShelfDataTable', () {
    testWidgets('has a 34 px header with upper case captions', (tester) async {
      await pumpThemed(
        tester,
        ShelfDataTable<Game>(columns: columns(), rows: games),
        width: 600,
      );

      expect(tester.getSize(find.byKey(const Key('table-header'))).height, 34);
      expect(find.text('TITLE'), findsOneWidget);
      expect(find.text('HOURS'), findsOneWidget);
    });

    testWidgets('has 48 px rows with the cells of every column', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ShelfDataTable<Game>(columns: columns(), rows: games),
        width: 600,
      );

      expect(tester.getSize(find.byKey(const Key('table-row-0'))).height, 48);
      expect(find.text('Hades'), findsOneWidget);
      expect(find.text('8 h'), findsOneWidget);
      expect(find.byKey(const Key('table-row-2')), findsOneWidget);
    });

    testWidgets('divides the width between the columns by their flex', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ShelfDataTable<Game>(columns: columns(), rows: games),
        width: 600,
      );

      final first = tester.getTopLeft(find.text('Hades')).dx;
      final second = tester.getTopLeft(find.text('41 h')).dx;
      expect(second - first, closeTo(600 * 3 / 4 - 0, 40));
    });

    testWidgets('marks a hovered row with the glow and a 2 px left line', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ShelfDataTable<Game>(columns: columns(), rows: games, onRowTap: (_) {}),
        width: 600,
      );
      expect(rowDecoration(tester, 1).color, isNull);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const Key('table-row-1'))),
      );
      await tester.pump();

      expect(rowDecoration(tester, 1).color, tokens.glowSoft);
      final line = tester.widget<ColoredBox>(
        find.byKey(const Key('table-row-1-line')),
      );
      expect(line.color, tokens.glow);
      expect(
        tester.getSize(find.byKey(const Key('table-row-1-line'))).width,
        2,
      );
    });

    testWidgets('tints a selected row with the soft accent', (tester) async {
      await pumpThemed(
        tester,
        ShelfDataTable<Game>(
          columns: columns(),
          rows: games,
          isSelected: (game) => game.title == 'Celeste',
        ),
        width: 600,
      );

      expect(rowDecoration(tester, 1).color, tokens.accentSoft);
      expect(rowDecoration(tester, 0).color, isNull);
    });

    testWidgets('reports the tapped row', (tester) async {
      Game? tapped;
      await pumpThemed(
        tester,
        ShelfDataTable<Game>(
          columns: columns(),
          rows: games,
          onRowTap: (game) => tapped = game,
        ),
        width: 600,
      );

      await tester.tap(find.text('Celeste'));

      expect(tapped?.title, 'Celeste');
    });

    testWidgets('adds a checkbox column when rows can be selected', (
      tester,
    ) async {
      final changes = <(String, bool)>[];
      await pumpThemed(
        tester,
        ShelfDataTable<Game>(
          columns: columns(),
          rows: games,
          isSelected: (game) => game.title == 'Hades',
          onSelectionChanged: (game, selected) =>
              changes.add((game.title, selected)),
          onSelectAll: (_) {},
        ),
        width: 600,
      );

      expect(find.byKey(const Key('table-row-0-check')), findsOneWidget);
      await tester.tap(find.byKey(const Key('table-row-1-check')));
      await tester.tap(find.byKey(const Key('table-row-0-check')));

      expect(changes, [('Celeste', true), ('Hades', false)]);
    });

    testWidgets(
      'shows the state of the select-all checkbox and reports a tap',
      (tester) async {
        bool? requested;
        await pumpThemed(
          tester,
          ShelfDataTable<Game>(
            columns: columns(),
            rows: games,
            isSelected: (game) => game.title == 'Hades',
            onSelectionChanged: (game, selected) {},
            onSelectAll: (all) => requested = all,
          ),
          width: 600,
        );

        expect(find.byIcon(Icons.remove), findsOneWidget);

        await tester.tap(find.byKey(const Key('table-select-all')));

        expect(requested, isTrue);
      },
    );
  });

  group('ShelfListRow', () {
    testWidgets(
      'is at least 48 px high with leading, title, subtitle and trailing',
      (tester) async {
        await pumpThemed(
          tester,
          const ShelfListRow(
            leading: Icon(Icons.games),
            title: 'Hades',
            subtitle: '41 h played',
            trailing: Text('Playing'),
          ),
          width: 400,
        );

        expect(
          tester.getSize(find.byType(ShelfListRow)).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getCenter(find.byIcon(Icons.games)).dx,
          lessThan(tester.getCenter(find.text('Hades')).dx),
        );
        expect(
          tester.getCenter(find.text('Playing')).dx,
          greaterThan(tester.getCenter(find.text('Hades')).dx),
        );
        expect(find.text('41 h played'), findsOneWidget);
      },
    );

    testWidgets('highlights when selected and reports a tap', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        ShelfListRow(title: 'Hades', selected: true, onTap: () => taps++),
        width: 400,
      );

      final box = tester.widget<DecoratedBox>(
        find.byKey(const Key('list-row-surface')),
      );
      expect((box.decoration as BoxDecoration).color, tokens.accentSoft);

      await tester.tap(find.text('Hades'));
      expect(taps, 1);
    });
  });

  goldenInBothThemes(
    'table',
    () => Column(
      children: [
        ShelfDataTable<Game>(
          columns: columns(),
          rows: games,
          isSelected: (game) => game.title == 'Celeste',
          onSelectionChanged: (game, selected) {},
          onSelectAll: (_) {},
        ),
        const SizedBox(height: 16),
        const ShelfListRow(
          leading: Icon(Icons.games),
          title: 'Hades',
          subtitle: '41 h played',
          trailing: Text('Playing'),
        ),
      ],
    ),
    size: const Size(640, 340),
    width: 600,
  );
}
