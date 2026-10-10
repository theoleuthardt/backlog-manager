import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/palette_registry.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show backlog, pumpLibrary;

String location(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

Future<ProviderContainer> openPalette(
  WidgetTester tester, {
  List<BacklogEntry>? entries,
}) async {
  final container = await pumpLibrary(
    tester,
    FakeBacklogApi(entries: entries ?? backlog),
    height: 900,
  );
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  return container;
}

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('palette-input')), text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ctrl+K opens the palette with the actions', (tester) async {
    await openPalette(tester);

    expect(find.byKey(const Key('command-palette')), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.text('GAMES'), findsNothing);
    expect(find.byKey(const Key('palette-action-add-game')), findsOneWidget);
    expect(find.text('Ctrl+N'), findsOneWidget);
  });

  testWidgets('Esc closes it', (tester) async {
    final container = await openPalette(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('command-palette')), findsNothing);
    expect(container.read(paletteOpenProvider), isFalse);
  });

  testWidgets('lists the games that match, best first', (tester) async {
    await openPalette(tester);

    await type(tester, 'tu');

    expect(find.text('GAMES'), findsOneWidget);
    expect(find.byKey(const Key('palette-game-6')), findsOneWidget);
    expect(find.text('Completed · 14 of 12 h'), findsOneWidget);
  });

  testWidgets('Enter on a game opens it in the library', (tester) async {
    final container = await openPalette(tester);

    await type(tester, 'celeste');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('command-palette')), findsNothing);
    expect(location(container), '${AppRoutes.library}?entry=2');
  });

  testWidgets('Enter on an action runs it', (tester) async {
    final container = await openPalette(tester);

    await type(tester, 'settings');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(location(container), AppRoutes.settings);
  });

  testWidgets('arrow down moves the highlight from a game to an action', (
    tester,
  ) async {
    final container = await openPalette(tester);
    var ran = false;
    container
        .read(paletteRegistryProvider.notifier)
        .register(
          PaletteAction(
            id: 'edit',
            label: 'Edit things',
            run: () => ran = true,
          ),
        );
    await tester.pumpAndSettle();

    await type(tester, 'e');
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(ran, isTrue);
    expect(location(container), AppRoutes.library);
  });

  testWidgets('arrow down picks the next game', (tester) async {
    final container = await openPalette(tester);

    await type(tester, 'e');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(location(container), '${AppRoutes.library}?entry=4');
  });

  testWidgets('arrow up from the first row wraps to the last one', (
    tester,
  ) async {
    final container = await openPalette(tester);
    final ran = <String>[];
    container.read(paletteRegistryProvider.notifier)
      ..register(
        PaletteAction(id: 'zz-a', label: 'zzA', run: () => ran.add('a')),
      )
      ..register(
        PaletteAction(id: 'zz-b', label: 'zzBBB', run: () => ran.add('b')),
      );
    await tester.pumpAndSettle();

    await type(tester, 'zz');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(ran, ['b']);
  });

  testWidgets('a click runs an action', (tester) async {
    final container = await openPalette(tester);

    await tester.tap(find.byKey(const Key('palette-action-add-game')));
    await tester.pumpAndSettle();

    expect(container.read(addGameRequestProvider), 1);
    expect(find.byKey(const Key('command-palette')), findsNothing);
  });

  testWidgets('says so when nothing matches', (tester) async {
    await openPalette(tester);

    await type(tester, 'qqqqq');

    expect(find.byKey(const Key('palette-empty')), findsOneWidget);
  });

  testWidgets('the shortcut of an action runs it without the palette', (
    tester,
  ) async {
    final container = await pumpLibrary(
      tester,
      FakeBacklogApi(entries: backlog),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(container.read(addGameRequestProvider), 1);
  });

  testWidgets('features can register their own action', (tester) async {
    final container = await openPalette(tester);
    var ran = false;
    container
        .read(paletteRegistryProvider.notifier)
        .register(
          PaletteAction(
            id: 'sync-steam',
            label: 'Sync Steam playtimes',
            shortcut: const PaletteShortcut(
              LogicalKeyboardKey.keyS,
              shift: true,
            ),
            run: () => ran = true,
          ),
        );
    await tester.pumpAndSettle();

    await type(tester, 'sync steam');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(ran, isTrue);
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the palette in $themeId', tags: 'golden', (
      tester,
    ) async {
      final container = await openPalette(tester);
      container.read(themeIdProvider.notifier).select(themeId);
      await tester.pumpAndSettle();
      await type(tester, 'e');

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/palette_$themeId.png'),
      );
    });
  }
}
