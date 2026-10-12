import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/features/startup/startup_splash.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design/widgets/harness.dart';

class _Session extends SessionNotifier {
  _Session(this.initial);

  final SessionState initial;

  @override
  SessionState build() => initial;
}

const _app = Text('the app', key: Key('the-app'));

Future<ProviderContainer> pump(
  WidgetTester tester, {
  SessionState session = const SessionSignedOut(),
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(() => _Session(session))],
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: themed('shelfOled', const StartupSplash(child: _app)),
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(StartupSplash)));
}

void main() {
  late bool saved;

  setUp(() {
    saved = atmosphereMotion;
    atmosphereMotion = true;
  });
  tearDown(() => atmosphereMotion = saved);

  testWidgets('shows the Saturn and the wordmark over the app', (tester) async {
    await pump(tester, session: const SessionLoading());
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
    expect(find.byKey(const Key('startup-saturn')), findsOneWidget);
    expect(find.byKey(const Key('startup-wordmark')), findsOneWidget);
    expect(find.byKey(const Key('the-app')), findsOneWidget);
  });

  testWidgets('ends by itself after the animation when the session is known', (
    tester,
  ) async {
    await pump(tester);

    await tester.pump(startupSplashDuration);
    await tester.pump(startupSplashDuration);
    await tester.pump();
    await tester.pump(startupSplashFade);
    await tester.pump(startupSplashFade);

    expect(find.byKey(const Key('startup-splash')), findsNothing);
    expect(find.byKey(const Key('the-app')), findsOneWidget);
  });

  testWidgets('waits for the session check after the animation', (
    tester,
  ) async {
    final container = await pump(tester, session: const SessionLoading());

    await tester.pump(startupSplashDuration);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('startup-splash')), findsOneWidget);

    container.read(sessionProvider.notifier).signOut();
    await tester.pump();
    await tester.pump(startupSplashFade);
    await tester.pump(startupSplashFade);

    expect(find.byKey(const Key('startup-splash')), findsNothing);
  });

  testWidgets('a tap skips the animation', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('startup-splash')));
    await tester.pump();
    await tester.pump(startupSplashFade);
    await tester.pump(startupSplashFade);

    expect(find.byKey(const Key('startup-splash')), findsNothing);
  });

  testWidgets('is not shown when the system asks for less motion', (
    tester,
  ) async {
    await pump(tester, reducedMotion: true);

    expect(find.byKey(const Key('startup-splash')), findsNothing);
    expect(find.byKey(const Key('the-app')), findsOneWidget);
  });

  testWidgets('is not shown while the motion is off', (tester) async {
    atmosphereMotion = false;
    await pump(tester);

    expect(find.byKey(const Key('startup-splash')), findsNothing);
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the start animation in $themeId', tags: 'golden', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(
              () => _Session(const SessionLoading()),
            ),
          ],
          child: themed(
            themeId,
            const SizedBox(
              width: 1000,
              height: 640,
              child: StartupSplash(child: _app),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(StartupSplash),
        matchesGoldenFile('goldens/startup_$themeId.png'),
      );
    });
  }
}
