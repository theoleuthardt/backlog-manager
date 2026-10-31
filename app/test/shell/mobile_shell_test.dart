import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_harness.dart';

const phonePortrait = Size(402, 874);
const phoneLandscape = Size(874, 402);
const handheldDense = Size(732, 412);
const handheldLarge = Size(960, 540);

Future<Harness> pumpMobile(
  WidgetTester tester, {
  required Size size,
  String? location,
}) => pumpApp(tester, size: size, desktop: false, location: location);

void main() {
  group('a phone in portrait', () {
    testWidgets('has a top bar and a bottom bar instead of the window chrome', (
      tester,
    ) async {
      await pumpMobile(tester, size: phonePortrait);

      expect(find.byKey(const Key('mobile-top-bar')), findsOneWidget);
      expect(find.byKey(const Key('bottom-nav')), findsOneWidget);
      expect(find.byKey(const Key('title-bar')), findsNothing);
      expect(find.byKey(const Key('sidebar')), findsNothing);
      expect(find.byKey(const Key('status-bar')), findsNothing);
      expect(find.byKey(const Key('nav-rail')), findsNothing);
    });

    testWidgets('the bottom bar opens the main pages', (tester) async {
      final app = await pumpMobile(tester, size: phonePortrait);

      await tester.tap(find.byKey(const Key('bottom-nav-library')));
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.library);
      expect(
        find.descendant(
          of: find.byKey(const Key('mobile-top-bar')),
          matching: find.text('Library'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('bottom-nav-space')));
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.space);

      await tester.tap(find.byKey(const Key('bottom-nav-home')));
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.home);
    });

    testWidgets('More opens every item of the sidebar', (tester) async {
      final app = await pumpMobile(tester, size: phonePortrait);

      await tester.tap(find.byKey(const Key('nav-more')));
      await tester.pumpAndSettle();

      for (final label in [
        'Home',
        'Library',
        'Shared Space',
        'Add Game',
        'Steam Sync',
        'Import CSV',
        'Export CSV',
        'Appearance',
        'Settings',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(const Key('nav-drawer')),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.byKey(const Key('account-row')), findsOneWidget);
      expect(find.byKey(const Key('sidebar-themes')), findsOneWidget);
      expect(
        find.text('Shortcuts'),
        findsNothing,
        reason: 'keyboard shortcuts are of no use without a keyboard',
      );

      await tester.tap(find.byKey(const Key('nav-steam')));
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.steam);
      expect(find.byKey(const Key('nav-drawer')), findsNothing);
    });

    testWidgets('the top bar shows the counts of the page', (tester) async {
      final app = await pumpMobile(tester, size: phonePortrait);

      app.container
          .read(shellStatusProvider.notifier)
          .update(counts: '148 games');
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('mobile-top-bar')),
          matching: find.text('148 games'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the inspector fills the screen', (tester) async {
      final app = await pumpMobile(tester, size: phonePortrait);

      app.container
          .read(shellInspectorProvider.notifier)
          .show(const SizedBox.expand(key: Key('fake-inspector')));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(const Key('inspector'))).width,
        phonePortrait.width,
      );
      expect(find.byKey(const Key('resize-inspector')), findsNothing);
    });
  });

  for (final (name, size) in [
    ('a phone in landscape', phoneLandscape),
    ('a dense handheld (Retroid Pocket 6, AYN Odin 3)', handheldDense),
    ('a large handheld', handheldLarge),
  ]) {
    group(name, () {
      testWidgets('has a top bar and a navigation rail', (tester) async {
        await pumpMobile(tester, size: size);

        expect(find.byKey(const Key('mobile-top-bar')), findsOneWidget);
        expect(find.byKey(const Key('nav-rail')), findsOneWidget);
        expect(find.byKey(const Key('bottom-nav')), findsNothing);
        expect(find.byKey(const Key('sidebar')), findsNothing);
        expect(find.byKey(const Key('status-bar')), findsNothing);
      });

      testWidgets('the rail opens the main pages and More', (tester) async {
        final app = await pumpMobile(tester, size: size);

        await tester.tap(find.byKey(const Key('rail-library')));
        await tester.pumpAndSettle();
        expect(app.location, AppRoutes.library);

        await tester.tap(find.byKey(const Key('nav-more')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('nav-drawer')), findsOneWidget);
      });
    });
  }

  group('the pages of a handheld', () {
    testWidgets('Add Game in the rail asks for a new game', (tester) async {
      final app = await pumpMobile(tester, size: handheldLarge);
      final before = app.container.read(addGameRequestProvider);

      await tester.tap(find.byKey(const Key('rail-add-game')));
      await tester.pumpAndSettle();

      expect(app.container.read(addGameRequestProvider), before + 1);
    });

    testWidgets('settings has a way back', (tester) async {
      final app = await pumpMobile(tester, size: handheldLarge);
      await app.go(AppRoutes.library);
      await app.go(AppRoutes.settings);

      expect(find.byKey(const Key('mobile-top-bar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-back')));
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.library);
    });
  });

  testWidgets('turning the device keeps the page and its state', (
    tester,
  ) async {
    await pumpMobile(tester, size: phonePortrait, location: AppRoutes.library);
    final page = tester.element(find.byKey(const Key('main-content')));

    for (final size in const [phoneLandscape, Size(1180, 820), phonePortrait]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const Key('main-content'))),
        same(page),
        reason: '$size',
      );
    }
  });

  testWidgets('the desktop keeps its window at a small size', (tester) async {
    await pumpApp(tester, size: const Size(800, 600));

    expect(find.byKey(const Key('title-bar')), findsOneWidget);
    expect(find.byKey(const Key('sidebar')), findsOneWidget);
    expect(find.byKey(const Key('status-bar')), findsOneWidget);
    expect(find.byKey(const Key('mobile-top-bar')), findsNothing);
  });

  group('goldens of the mobile window', () {
    for (final (name, size) in [
      ('phone_portrait', phonePortrait),
      ('phone_landscape', phoneLandscape),
      ('handheld_dense', handheldDense),
      ('handheld_large', handheldLarge),
    ]) {
      testWidgets('matches the layout on $name', tags: 'golden', (
        tester,
      ) async {
        final app = await pumpMobile(tester, size: size);
        await app.go(AppRoutes.home);
        app.container
            .read(shellStatusProvider.notifier)
            .update(counts: '148 games');
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/mobile_window_$name.png'),
        );
      });
    }

    testWidgets('matches the open drawer on a phone', tags: 'golden', (
      tester,
    ) async {
      await pumpMobile(tester, size: phonePortrait);
      await tester.tap(find.byKey(const Key('nav-more')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_window_drawer.png'),
      );
    });

    for (final (name, size) in [
      ('phone_portrait', phonePortrait),
      ('handheld_large', handheldLarge),
    ]) {
      testWidgets('matches the button hints on $name', tags: 'golden', (
        tester,
      ) async {
        final app = await pumpMobile(tester, size: size);
        await app.go(AppRoutes.home);
        app.container.read(gamepadInUseProvider.notifier).set(inUse: true);
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/mobile_window_hints_$name.png'),
        );
      });
    }
  });

  group('navigation (#558)', () {
    testWidgets('More is a bottom sheet that can be dragged', (tester) async {
      await pumpMobile(tester, size: phonePortrait);

      await tester.tap(find.byKey(const Key('nav-more')));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byKey(const Key('nav-drawer')));
      expect(sheet.bottom, closeTo(phonePortrait.height, 1));
      expect(sheet.width, closeTo(phonePortrait.width, 1));
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('More can be dragged down on a handheld without overflow', (
      tester,
    ) async {
      await pumpMobile(tester, size: handheldDense);
      await tester.tap(find.byKey(const Key('nav-more')));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('nav-drawer')),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the theme creator in More closes the sheet', (tester) async {
      final app = await pumpMobile(tester, size: phonePortrait);
      await tester.tap(find.byKey(const Key('nav-more')));
      await tester.pumpAndSettle();

      final creator = find.byKey(const Key('sidebar-theme-creator'));
      await tester.ensureVisible(creator);
      await tester.pumpAndSettle();
      await tester.tap(creator);
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.appearance);
      expect(find.byKey(const Key('nav-drawer')), findsNothing);
    });

    testWidgets('the rail is as high as the screen', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPadding);
      await pumpMobile(tester, size: handheldDense);

      final rail = tester.getRect(find.byKey(const Key('nav-rail')));
      expect(rail.top, 0);
      expect(rail.bottom, handheldDense.height);
    });

    testWidgets('the command palette starts below the status bar', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 59);
      addTearDown(tester.view.resetPadding);
      await pumpMobile(tester, size: phonePortrait);

      await tester.tap(find.byKey(const Key('mobile-palette')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final field = tester.getRect(find.byKey(const Key('palette-input')));
      expect(field.top, greaterThanOrEqualTo(59));
      expect(find.text('Ctrl+N'), findsNothing);
    });
  });
}
