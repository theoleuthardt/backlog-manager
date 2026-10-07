import 'dart:async';

import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/app_version.dart';
import 'package:backlog_manager/shell/navigation_counts.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:backlog_manager/shell/window_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';

const finished = SessionSignedIn(
  SessionUser(name: 'Theo', email: 'theo@example.com', setupCompleted: true),
);

class FixedSession extends SessionNotifier {
  FixedSession(this.initial);

  final SessionState initial;

  @override
  SessionState build() => initial;
}

class RecordingWindowControls implements WindowControls {
  final calls = <String>[];

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> toggleMaximize() async => calls.add('maximize');

  @override
  Future<void> startDragging() async => calls.add('drag');
}

class Harness {
  Harness(this.tester, this.controls, this.tokens);

  final WidgetTester tester;
  final RecordingWindowControls controls;
  final MemoryTokenStore tokens;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  String get location {
    final router = container.read(routerProvider);
    return router.routerDelegate.currentConfiguration.uri.path;
  }

  Future<void> go(String path) async {
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  SessionState session = finished,
  String? location,
  TargetPlatform platform = TargetPlatform.macOS,
  Size size = const Size(1440, 900),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controls = RecordingWindowControls();
  final tokens = MemoryTokenStore('jwt');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => FixedSession(session)),
        shelfThemeProvider.overrideWith((ref) {
          final theme = resolveTheme(ref.watch(themeIdProvider), const []);
          return buildShelfTheme(ShelfTokens.forTheme(theme))
              .copyWith(platform: platform);
        }),
        windowControlsProvider.overrideWithValue(controls),
        tokenStoreProvider.overrideWithValue(tokens),
        appVersionProvider.overrideWith((ref) async => 'v0.9.0'),
      ],
      child: const BacklogManagerApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  final harness = Harness(tester, controls, tokens);
  if (location != null) await harness.go(location);
  return harness;
}

Finder inMain(Finder matching) => find.descendant(
  of: find.byKey(const Key('main-content')),
  matching: matching,
);

void main() {
  group('the main window', () {
    testWidgets('has the title bar, sidebar and status bar of the design', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(tester.getSize(find.byKey(const Key('title-bar'))).height, 52);
      expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 232);
      expect(tester.getSize(find.byKey(const Key('status-bar'))).height, 28);
      expect(find.byKey(const Key('main-content')), findsOneWidget);
    });

    testWidgets('lists the navigation sections and items', (tester) async {
      await pumpApp(tester);

      for (final label in [
        'BACKLOG',
        'ADD',
        'PERSONALISE',
        'Home',
        'Library',
        'Shared space',
        'Add game',
        'Steam sync',
        'Import CSV',
        'Export CSV',
        'Appearance',
        'Settings',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(const Key('sidebar')),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
    });

    testWidgets('marks the item of the current page as selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, location: AppRoutes.library);

      Matcher selected(bool value) => value
          ? isSemantics(isSelected: true)
          : isNot(isSemantics(isSelected: true));
      SemanticsNode node(String id) =>
          tester.getSemantics(find.byKey(Key('nav-$id')));

      expect(node('library'), selected(true));
      expect(node('home'), selected(false));
      expect(node('steam'), selected(false));
      handle.dispose();
    });

    testWidgets('navigates with the sidebar', (tester) async {
      final app = await pumpApp(tester);

      await tester.tap(find.byKey(const Key('nav-steam')));
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.steam);
      expect(inMain(find.text('Steam sync')), findsOneWidget);
    });

    testWidgets('shows the title of the current page in the title bar', (
      tester,
    ) async {
      await pumpApp(tester, location: AppRoutes.library);

      expect(
        tester.widget<Text>(find.byKey(const Key('title-bar-title'))).data,
        'Library',
      );
    });

    testWidgets('collapses the sidebar from the title bar and opens it again', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('sidebar-toggle')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 0);

      await tester.tap(find.byKey(const Key('sidebar-toggle')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 232);
    });

    testWidgets('hides a collapsed sidebar from focus and screen readers', (
      tester,
    ) async {
      await pumpApp(tester);
      bool excludedFromFocus() => tester
          .widget<ExcludeFocus>(
            find
                .descendant(
                  of: find.byKey(const Key('sidebar')),
                  matching: find.byType(ExcludeFocus),
                )
                .first,
          )
          .excluding;
      bool excludedFromSemantics() => tester
          .widget<ExcludeSemantics>(
            find
                .descendant(
                  of: find.byKey(const Key('sidebar')),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding;
      expect(excludedFromFocus(), isFalse);
      expect(excludedFromSemantics(), isFalse);

      await tester.tap(find.byKey(const Key('sidebar-toggle')));
      await tester.pumpAndSettle();

      expect(excludedFromFocus(), isTrue);
      expect(excludedFromSemantics(), isTrue);
    });

    testWidgets('shows the inspector in its slot only while one is set', (
      tester,
    ) async {
      final app = await pumpApp(tester);
      expect(find.byKey(const Key('inspector')), findsNothing);

      app.container
          .read(shellInspectorProvider.notifier)
          .show(const Text('Details'));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(const Key('inspector'))).width, 380);
      expect(find.text('Details'), findsOneWidget);

      app.container.read(shellInspectorProvider.notifier).hide();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inspector')), findsNothing);
    });

    testWidgets('renders every page of the route table', (tester) async {
      final app = await pumpApp(tester);

      for (final path in [
        AppRoutes.home,
        AppRoutes.library,
        AppRoutes.steam,
        AppRoutes.import,
        AppRoutes.export,
        AppRoutes.creationTool,
        AppRoutes.appearance,
        AppRoutes.space,
        AppRoutes.settings,
      ]) {
        await app.go(path);

        expect(app.location, path, reason: path);
        expect(tester.takeException(), isNull, reason: path);
      }
    });
  });

  group('the status bar', () {
    testWidgets('shows the counts, the sync state and the version', (
      tester,
    ) async {
      final app = await pumpApp(tester);

      app.container
          .read(shellStatusProvider.notifier)
          .update(counts: '148 games', sync: 'Steam synced 2 min ago');
      await tester.pumpAndSettle();

      final bar = find.byKey(const Key('status-bar'));
      expect(
        find.descendant(of: bar, matching: find.text('148 games')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Steam synced 2 min ago')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('v0.9.0')),
        findsOneWidget,
      );
    });
  });

  group('the title bar', () {
    testWidgets('shows the search field with the shortcut of the platform', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('⌘K'), findsOneWidget);
    });

    testWidgets('shows Ctrl K away from macOS', (tester) async {
      await pumpApp(tester, platform: TargetPlatform.windows);
      expect(find.text('Ctrl K'), findsOneWidget);
    });

    testWidgets(
      'leaves room for the traffic lights on macOS and has no caption buttons',
      (tester) async {
        await pumpApp(tester);

        expect(find.byKey(const Key('caption-close')), findsNothing);
        final toggle = tester.getTopLeft(
          find.byKey(const Key('sidebar-toggle')),
        );
        expect(toggle.dx, greaterThanOrEqualTo(72));
      },
    );

    testWidgets('has caption buttons on the right on Windows and Linux', (
      tester,
    ) async {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        final app = await pumpApp(tester, platform: platform);

        await tester.tap(find.byKey(const Key('caption-minimize')));
        await tester.tap(find.byKey(const Key('caption-maximize')));
        await tester.tap(find.byKey(const Key('caption-close')));

        expect(app.controls.calls, ['minimize', 'maximize', 'close']);
        expect(
          tester.getTopRight(find.byKey(const Key('caption-close'))).dx,
          greaterThan(1400),
        );
      }
    });
  });

  group('the account row', () {
    testWidgets('shows the user at the bottom of the sidebar', (tester) async {
      await pumpApp(tester);

      final row = find.byKey(const Key('account-row'));
      expect(
        find.descendant(of: row, matching: find.text('Theo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('theo@example.com')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('T')),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(row).dy,
        closeTo(tester.getTopLeft(find.byKey(const Key('status-bar'))).dy, 0.5),
      );
    });

    testWidgets('logs out from the switcher and returns to sign-in', (
      tester,
    ) async {
      final app = await pumpApp(tester);

      await tester.tap(find.byKey(const Key('account-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.signIn);
      expect(find.byKey(const Key('sidebar')), findsNothing);
      expect(app.tokens.token, isNull);
    });

    testWidgets('switches the theme at runtime from the switcher', (
      tester,
    ) async {
      await pumpApp(tester);
      final before = Theme.of(tester.element(find.byKey(const Key('sidebar'))));

      await tester.tap(find.byKey(const Key('account-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      final after = Theme.of(tester.element(find.byKey(const Key('sidebar'))));
      expect(before.extension<ShelfTokens>()!.accent, const Color(0xFFF5A524));
      expect(
        after.extension<ShelfTokens>(),
        ShelfTokens.forTheme(resolveTheme('light', const [])),
      );
    });
  });

  group('the route guard', () {
    testWidgets('sends a signed-out user to sign-in', (tester) async {
      final app = await pumpApp(tester, session: const SessionSignedOut());

      await app.go(AppRoutes.library);

      expect(app.location, AppRoutes.signIn);
      expect(find.byKey(const Key('sidebar')), findsNothing);
      expect(find.byKey(const Key('page-sign-in')), findsOneWidget);
    });

    testWidgets('shows a loading state while the session is checked', (
      tester,
    ) async {
      await pumpApp(tester, session: const SessionLoading(), settle: false);

      expect(find.byKey(const Key('page-loading')), findsOneWidget);
      expect(find.byKey(const Key('sidebar')), findsNothing);
    });

    testWidgets('sends a user with an unfinished setup to the wizard', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        session: const SessionSignedIn(
          SessionUser(
            name: 'Theo',
            email: 't@example.com',
            setupCompleted: false,
          ),
        ),
      );

      await app.go(AppRoutes.library);

      expect(app.location, AppRoutes.setup);
      expect(find.byKey(const Key('page-setup')), findsOneWidget);
    });

    testWidgets('the app opens at sign-in when nobody is signed in', (
      tester,
    ) async {
      final app = await pumpApp(tester, session: const SessionSignedOut());

      expect(app.location, AppRoutes.signIn);
    });

    testWidgets('reacts when the session changes', (tester) async {
      final app = await pumpApp(tester, session: const SessionSignedOut());

      app.container.read(sessionProvider.notifier).signIn(finished.user);
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.home);
      expect(find.byKey(const Key('sidebar')), findsOneWidget);
    });
  });

  group('keyboard shortcuts', () {
    testWidgets('/ focuses the search field', (tester) async {
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('search-field')),
      );
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('Cmd+K opens the command palette on macOS and Esc closes it', (
      tester,
    ) async {
      final app = await pumpApp(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(app.container.read(paletteOpenProvider), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(app.container.read(paletteOpenProvider), isFalse);
    });

    testWidgets('Ctrl+K opens the command palette on Windows', (tester) async {
      final app = await pumpApp(tester, platform: TargetPlatform.windows);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(app.container.read(paletteOpenProvider), isTrue);
    });

    testWidgets('Esc closes the inspector', (tester) async {
      final app = await pumpApp(tester);
      app.container
          .read(shellInspectorProvider.notifier)
          .show(const Text('Details'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inspector')), findsNothing);
    });
  });

  group('Esc with a sheet open', () {
    testWidgets('closes the sheet and leaves the inspector visible', (
      tester,
    ) async {
      final app = await pumpApp(tester);
      app.container
          .read(shellInspectorProvider.notifier)
          .show(const Text('Details'));
      await tester.pumpAndSettle();
      unawaited(
        showShelfSheet<void>(
          tester.element(find.byKey(const Key('main-content'))),
          builder: (context) => const Text('Sheet body'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Sheet body'), findsNothing);
      expect(find.byKey(const Key('inspector')), findsOneWidget);
    });
  });

  group('back and forward', () {
    testWidgets('start disabled and follow the pages that were visited', (
      tester,
    ) async {
      final app = await pumpApp(tester);

      bool enabled(String key) =>
          tester
              .widget<IconButton>(
                find.descendant(
                  of: find.byKey(Key(key)),
                  matching: find.byType(IconButton),
                ),
              )
              .onPressed !=
          null;
      expect(enabled('nav-back'), isFalse);
      expect(enabled('nav-forward'), isFalse);

      await tester.tap(find.byKey(const Key('nav-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-steam')));
      await tester.pumpAndSettle();
      expect(enabled('nav-back'), isTrue);

      await tester.tap(find.byKey(const Key('nav-back')));
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.library);
      expect(enabled('nav-forward'), isTrue);

      await tester.tap(find.byKey(const Key('nav-forward')));
      await tester.pumpAndSettle();
      expect(app.location, AppRoutes.steam);
      expect(enabled('nav-forward'), isFalse);
    });

    testWidgets('lead back from the settings window', (tester) async {
      final app = await pumpApp(tester);
      await app.go(AppRoutes.settings);

      await tester.tap(find.byKey(const Key('nav-back')));
      await tester.pumpAndSettle();

      expect(app.location, AppRoutes.home);
    });

    testWidgets('forget the forward pages after a new visit', (tester) async {
      final app = await pumpApp(tester);
      await app.go(AppRoutes.library);
      await app.go(AppRoutes.steam);
      await tester.tap(find.byKey(const Key('nav-back')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav-import')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(const Key('nav-forward')),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('counts in the sidebar', () {
    testWidgets('show the number next to an item that has one', (tester) async {
      final app = await pumpApp(tester);

      app.container.read(navigationCountsProvider.notifier).set({
        'library': 148,
        'space': 12,
      });
      await tester.pumpAndSettle();

      final sidebar = find.byKey(const Key('sidebar'));
      expect(
        find.descendant(of: sidebar, matching: find.text('148')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sidebar, matching: find.text('12')),
        findsOneWidget,
      );
    });
  });

  group('golden of the main window', () {
    testWidgets('matches the layout of the Home window', (tester) async {
      final app = await pumpApp(tester);
      app.container.read(navigationCountsProvider.notifier).set({
        'library': 148,
        'space': 12,
      });
      app.container
          .read(shellStatusProvider.notifier)
          .update(counts: '148 games', sync: 'Steam synced 2 min ago');
      await app.go(AppRoutes.library);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/main_window_shelfOled.png'),
      );
    });
  });
}
