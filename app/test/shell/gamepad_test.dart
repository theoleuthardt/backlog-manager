import 'package:backlog_manager/auth/biometric_lock.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/gamepad.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/biometric_fakes.dart';
import '../data/fakes.dart';
import '../features/inspector/entry_inspector_test.dart' show celeste, hades;
import '../features/library/library_page_test.dart' show pumpLibrary;
import '../features/mobile_pages_test.dart' show resize;
import 'shell_harness.dart';

const handheld = Size(732, 412);

Future<Harness> pumpHandheld(WidgetTester tester, {String? location}) =>
    pumpApp(tester, size: handheld, desktop: false, location: location);

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  group('the buttons', () {
    test('map to their actions', () {
      expect(
        gamepadActionFor(LogicalKeyboardKey.gameButtonB),
        GamepadAction.back,
      );
      expect(
        gamepadActionFor(LogicalKeyboardKey.gameButtonX),
        GamepadAction.menu,
      );
      expect(
        gamepadActionFor(LogicalKeyboardKey.gameButtonY),
        GamepadAction.search,
      );
      expect(
        gamepadActionFor(LogicalKeyboardKey.gameButtonLeft1),
        GamepadAction.previousSection,
      );
      expect(
        gamepadActionFor(LogicalKeyboardKey.gameButtonRight1),
        GamepadAction.nextSection,
      );
      expect(
        gamepadActionFor(LogicalKeyboardKey.gameButtonStart),
        GamepadAction.settings,
      );
    });

    test('leave A and the D-pad to the framework', () {
      for (final key in [
        LogicalKeyboardKey.gameButtonA,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.keyK,
      ]) {
        expect(gamepadActionFor(key), isNull, reason: '$key');
      }
    });

    test('the shoulder buttons step through the main sections and Add', () {
      expect(sectionAfter(AppRoutes.home, forward: true), AppRoutes.library);
      expect(
        sectionAfter(AppRoutes.library, forward: true),
        addGameSection,
        reason: 'Add of the bottom bar, the search for a new game',
      );
      expect(
        sectionAfter(AppRoutes.library, forward: true, adding: true),
        AppRoutes.space,
      );
      expect(
        sectionAfter(AppRoutes.library, forward: false, adding: true),
        AppRoutes.library,
      );
      expect(sectionAfter(AppRoutes.space, forward: false), addGameSection);
      expect(sectionAfter(AppRoutes.space, forward: true), AppRoutes.home);
      expect(sectionAfter(AppRoutes.home, forward: false), AppRoutes.space);
      expect(sectionAfter(AppRoutes.steam, forward: true), AppRoutes.home);
    });
  });

  group('on a handheld', () {
    testWidgets('R1 opens the search for a new game after the library', (
      tester,
    ) async {
      final app = await pumpHandheld(tester, location: AppRoutes.library);

      await press(tester, LogicalKeyboardKey.gameButtonRight1);
      expect(find.text('Search for a game'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.gameButtonRight1);
      expect(find.text('Search for a game'), findsNothing);
      expect(app.location, AppRoutes.space);
    });

    testWidgets('R1 and L1 change the section', (tester) async {
      final app = await pumpHandheld(tester);

      await press(tester, LogicalKeyboardKey.gameButtonRight1);
      expect(app.location, AppRoutes.library);
      await press(tester, LogicalKeyboardKey.gameButtonLeft1);
      expect(app.location, AppRoutes.home);
    });

    testWidgets('Start opens the settings and B goes back', (tester) async {
      final app = await pumpHandheld(tester);
      await app.go(AppRoutes.library);

      await press(tester, LogicalKeyboardKey.gameButtonStart);
      expect(app.location, AppRoutes.settings);
      await press(tester, LogicalKeyboardKey.gameButtonB);
      expect(app.location, AppRoutes.library);
    });

    testWidgets('Y opens the command palette and B closes it', (tester) async {
      final app = await pumpHandheld(tester);

      await press(tester, LogicalKeyboardKey.gameButtonY);
      expect(find.byKey(const Key('command-palette')), findsOneWidget);
      await press(tester, LogicalKeyboardKey.gameButtonB);
      expect(find.byKey(const Key('command-palette')), findsNothing);
      expect(app.location, AppRoutes.home);
    });

    testWidgets('B closes a sheet before it goes back', (tester) async {
      final app = await pumpHandheld(tester);
      await app.go(AppRoutes.library);
      app.container.read(addGameRequestProvider.notifier).request();
      await tester.pumpAndSettle();
      expect(find.text('Search for a game'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.gameButtonB);

      expect(find.text('Search for a game'), findsNothing);
      expect(app.location, AppRoutes.library);
    });

    testWidgets('B closes the inspector', (tester) async {
      final app = await pumpHandheld(tester);
      app.container
          .read(shellInspectorProvider.notifier)
          .show(const SizedBox.expand(key: Key('fake-inspector')));
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.gameButtonB);

      expect(find.byKey(const Key('fake-inspector')), findsNothing);
    });

    testWidgets('the system back goes back in the history', (tester) async {
      final app = await pumpHandheld(tester);
      await app.go(AppRoutes.library);
      await app.go(AppRoutes.steam);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.library);
    });

    testWidgets('the D-pad finds the first control when nothing has focus', (
      tester,
    ) async {
      await pumpHandheld(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await press(tester, LogicalKeyboardKey.arrowDown);

      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull);
      expect(focused, isNot(isA<FocusScopeNode>()));
    });

    testWidgets('X opens the menu of the focused game, A opens the game', (
      tester,
    ) async {
      await pumpLibrary(
        tester,
        FakeBacklogApi(entries: const [hades, celeste]),
        overrides: [isDesktopProvider.overrideWithValue(false)],
      );
      await resize(tester, handheld);
      await tester.scrollUntilVisible(
        find.byKey(const Key('library-tile-1')),
        100,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('page-library')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      Focus.of(tester.element(find.byKey(const Key('library-tile-1'))))
          .requestFocus();
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.gameButtonX);
      expect(
        find.widgetWithText(SubmenuButton, 'Move to status'),
        findsOneWidget,
      );
      await press(tester, LogicalKeyboardKey.gameButtonB);
      expect(
        find.widgetWithText(SubmenuButton, 'Move to status'),
        findsNothing,
      );

      await press(tester, LogicalKeyboardKey.gameButtonA);
      expect(find.byKey(const Key('entry-inspector')), findsOneWidget);
    });
  });

  testWidgets('B closes the More sheet before it goes back', (tester) async {
    final app = await pumpApp(
      tester,
      size: const Size(402, 874),
      desktop: false,
    );
    await app.go(AppRoutes.library);
    await tester.tap(find.byKey(const Key('nav-more')));
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.gameButtonB);

    expect(find.byKey(const Key('nav-drawer')), findsNothing);
    expect(app.location, AppRoutes.library);
  });

  testWidgets('a tablet in the desktop layout also goes back', (tester) async {
    final app = await pumpApp(
      tester,
      size: const Size(1180, 820),
      desktop: false,
    );
    await app.go(AppRoutes.library);
    await app.go(AppRoutes.steam);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(app.location, AppRoutes.library);
  });

  group('the swipe from the left edge', () {
    const phone = Size(402, 874);

    Future<Harness> twoPages(WidgetTester tester) async {
      final app = await pumpApp(tester, size: phone, desktop: false);
      await app.go(AppRoutes.library);
      await app.go(AppRoutes.steam);
      return app;
    }

    testWidgets(
      'goes back on iOS',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        final app = await twoPages(tester);

        await tester.dragFrom(const Offset(4, 500), const Offset(160, 0));
        await tester.pumpAndSettle();

        expect(app.location, AppRoutes.library);
      },
    );

    testWidgets(
      'closes a sheet on iOS before it goes back',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        final app = await twoPages(tester);
        app.container.read(addGameRequestProvider.notifier).request();
        await tester.pumpAndSettle();
        expect(find.text('Search for a game'), findsOneWidget);

        await tester.dragFrom(const Offset(4, 500), const Offset(160, 0));
        await tester.pumpAndSettle();

        expect(find.text('Search for a game'), findsNothing);
        expect(app.location, AppRoutes.steam);
      },
    );

    testWidgets(
      'a short fling from the edge goes back too',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        final app = await twoPages(tester);

        await tester.flingFrom(const Offset(4, 500), const Offset(60, 0), 800);
        await tester.pumpAndSettle();

        expect(app.location, AppRoutes.library);
      },
    );

    testWidgets(
      'needs to start at the edge and to go far enough',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        final app = await twoPages(tester);

        await tester.dragFrom(const Offset(120, 500), const Offset(160, 0));
        await tester.pumpAndSettle();
        await tester.dragFrom(const Offset(4, 500), const Offset(20, 0));
        await tester.pumpAndSettle();

        expect(app.location, AppRoutes.steam);
      },
    );

    testWidgets(
      'is left to the system on Android',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
        final app = await twoPages(tester);

        await tester.dragFrom(const Offset(4, 500), const Offset(160, 0));
        await tester.pumpAndSettle();

        expect(app.location, AppRoutes.steam);
      },
    );
  });

  testWidgets('signed out only B works', (tester) async {
    final app = await pumpApp(
      tester,
      size: handheld,
      desktop: false,
      session: const SessionSignedOut(),
    );
    final before = app.location;

    await press(tester, LogicalKeyboardKey.gameButtonRight1);
    await press(tester, LogicalKeyboardKey.gameButtonStart);

    expect(app.location, before);
  });

  testWidgets('back does nothing behind the lock screen', (tester) async {
    final app = await pumpApp(
      tester,
      size: handheld,
      desktop: false,
      extraOverrides: [
        biometricUnlockAtStartProvider.overrideWithValue(true),
        biometricAuthProvider.overrideWithValue(
          FakeBiometricAuth()..passes = false,
        ),
      ],
    );
    await app.go(AppRoutes.library);
    await app.go(AppRoutes.steam);
    expect(find.byKey(const Key('biometric-lock')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await press(tester, LogicalKeyboardKey.gameButtonB);
    await press(tester, LogicalKeyboardKey.gameButtonRight1);
    await press(tester, LogicalKeyboardKey.gameButtonStart);

    expect(app.location, AppRoutes.steam);
  });

  testWidgets('the desktop ignores the gamepad buttons', (tester) async {
    final app = await pumpApp(tester);

    await press(tester, LogicalKeyboardKey.gameButtonRight1);
    expect(app.location, AppRoutes.home);
  });
}
