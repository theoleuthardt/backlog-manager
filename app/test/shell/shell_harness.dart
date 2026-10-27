import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/app_version.dart';
import 'package:backlog_manager/shell/window_controls.dart';
import 'package:flutter/material.dart';
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
  bool desktop = true,
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
        isDesktopProvider.overrideWithValue(desktop),
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
