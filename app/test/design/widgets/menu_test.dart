import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Widget menuButton(List<ShelfMenuEntry> entries) {
  return ShelfMenuAnchor(
    entries: entries,
    builder: (context, controller) =>
        TextButton(onPressed: controller.open, child: const Text('Open')),
  );
}

void main() {
  final tokens = tokensOf('shelfOled');

  group('ShelfMenuAnchor', () {
    testWidgets('opens its items from the trigger and closes after a choice', (
      tester,
    ) async {
      var chosen = 0;
      await pumpThemed(
        tester,
        menuButton([
          ShelfMenuItem(label: 'Open details', onSelected: () => chosen++),
        ]),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Open details'), findsOneWidget);

      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();

      expect(chosen, 1);
      expect(find.text('Open details'), findsNothing);
    });

    testWidgets('shows the shortcut hint on the right of an item', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        menuButton([
          ShelfMenuItem(label: 'Add game', shortcut: '⌘N', onSelected: () {}),
        ]),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        tester.getCenter(find.text('⌘N')).dx,
        greaterThan(tester.getCenter(find.text('Add game')).dx),
      );
    });

    testWidgets('writes a danger item in the danger colour', (tester) async {
      await pumpThemed(
        tester,
        menuButton([
          ShelfMenuItem(label: 'Delete', danger: true, onSelected: () {}),
        ]),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text('Delete')).style?.color ?? tokens.danger,
        tokens.danger,
      );
      final button = tester.widget<MenuItemButton>(find.byType(MenuItemButton));
      expect(button.style!.foregroundColor!.resolve({}), tokens.danger);
    });

    testWidgets('fills the hovered item with the accent', (tester) async {
      await pumpThemed(
        tester,
        menuButton([ShelfMenuItem(label: 'Open details', onSelected: () {})]),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final button = tester.widget<MenuItemButton>(find.byType(MenuItemButton));

      expect(
        button.style!.backgroundColor!.resolve({WidgetState.hovered}),
        tokens.accent,
      );
      expect(
        button.style!.foregroundColor!.resolve({WidgetState.hovered}),
        tokens.onAccent,
      );
      expect(button.style!.backgroundColor!.resolve({}), Colors.transparent);
    });

    testWidgets('is a 30 px item on surface2 with the strong border', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        menuButton([ShelfMenuItem(label: 'Open details', onSelected: () {})]),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final button = tester.widget<MenuItemButton>(find.byType(MenuItemButton));
      expect(button.style!.minimumSize!.resolve({})!.height, 30);
      final menu = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
      expect(menu.style!.backgroundColor!.resolve({}), tokens.surface2);
    });

    testWidgets(
      'keeps the menu open for an item that stays open and shows its check',
      (tester) async {
        var toggled = 0;
        await pumpThemed(
          tester,
          menuButton([
            ShelfMenuItem(
              label: 'RPG',
              checked: true,
              keepOpen: true,
              onSelected: () => toggled++,
            ),
          ]),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check), findsOneWidget);

        await tester.tap(find.text('RPG'));
        await tester.pumpAndSettle();

        expect(toggled, 1);
        expect(find.text('RPG'), findsOneWidget);
      },
    );

    testWidgets('opens a submenu', (tester) async {
      String? status;
      await pumpThemed(
        tester,
        menuButton([
          ShelfMenuItem(
            label: 'Move to status',
            submenu: [
              ShelfMenuItem(
                label: 'Completed',
                onSelected: () => status = 'Completed',
              ),
            ],
          ),
        ]),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move to status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(status, 'Completed');
    });

    testWidgets('separates groups of items with a divider', (tester) async {
      await pumpThemed(
        tester,
        menuButton([
          ShelfMenuItem(label: 'Open details', onSelected: () {}),
          const ShelfMenuDivider(),
          ShelfMenuItem(label: 'Delete', danger: true, onSelected: () {}),
        ]),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu-divider')), findsOneWidget);
    });

    testWidgets('opens with the keyboard and closes with Esc', (tester) async {
      await pumpThemed(
        tester,
        menuButton([ShelfMenuItem(label: 'Open details', onSelected: () {})]),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Open details'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Open details'), findsNothing);
    });
  });

  group('ContextMenuRegion', () {
    testWidgets(
      'opens at the pointer on a right click and not on a left click',
      (tester) async {
        await pumpThemed(
          tester,
          ContextMenuRegion(
            entries: [ShelfMenuItem(label: 'Open details', onSelected: () {})],
            child: const SizedBox(
              width: 300,
              height: 200,
              child: Text('Cover'),
            ),
          ),
        );

        await tester.tap(find.text('Cover'));
        await tester.pumpAndSettle();
        expect(find.text('Open details'), findsNothing);

        await tester.tapAt(const Offset(120, 90), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(find.text('Open details'), findsOneWidget);
        final menu = tester.getTopLeft(find.text('Open details'));
        expect((menu.dx - 120).abs(), lessThan(40));
        expect((menu.dy - 90).abs(), lessThan(40));
      },
    );
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: menu in $themeId', tags: 'golden', (tester) async {
      tester.view.physicalSize = const Size(420, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpThemed(
        tester,
        menuButton([
          ShelfMenuItem(
            label: 'Open details',
            shortcut: '↵',
            onSelected: () {},
          ),
          ShelfMenuItem(
            label: 'Select',
            icon: Icons.check_box_outlined,
            onSelected: () {},
          ),
          ShelfMenuItem(label: 'Move to status', submenu: const []),
          ShelfMenuItem(
            label: 'RPG',
            checked: true,
            keepOpen: true,
            onSelected: () {},
          ),
          ShelfMenuItem(
            label: 'Co-op',
            checked: false,
            keepOpen: true,
            onSelected: () {},
          ),
          const ShelfMenuDivider(),
          ShelfMenuItem(label: 'Delete', danger: true, onSelected: () {}),
        ]),
        themeId: themeId,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/menu_$themeId.png'),
      );
    });
  }
}
