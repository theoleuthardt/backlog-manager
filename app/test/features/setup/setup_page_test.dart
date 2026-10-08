import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/auth/auth_api.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth/fakes.dart';
import 'setup_controller_test.dart' show FakeUserApi;

class Unfinished extends SessionNotifier {
  @override
  SessionState build() => const SessionSignedIn(
    SessionUser(name: 'Theo', email: 'theo@example.com', setupCompleted: false),
  );
}

class Harness {
  Harness(this.tester, this.users, this.opened);

  final WidgetTester tester;
  final FakeUserApi users;
  final List<Uri> opened;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  String get location => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;
}

Future<Harness> pumpSetup(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final users = FakeUserApi();
  final opened = <Uri>[];
  final auth = FakeAuthApi()
    ..onCurrentUser = () async => const SessionUser(
      name: 'Theo',
      email: 'theo@example.com',
      setupCompleted: true,
    );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(Unfinished.new),
        userApiProvider.overrideWithValue(users),
        authApiProvider.overrideWithValue(auth),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore('jwt')),
        urlOpenerProvider.overrideWithValue(opened.add),
      ],
      child: const BacklogManagerApp(),
    ),
  );
  await tester.pumpAndSettle();
  return Harness(tester, users, opened);
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('setup-next')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unfinished user lands on the wizard with its stepper', (
    tester,
  ) async {
    final app = await pumpSetup(tester);

    expect(app.location, AppRoutes.setup);
    expect(find.byKey(const Key('page-setup')), findsOneWidget);
    expect(find.text('Welcome to Backlog'), findsOneWidget);
    for (final step in ['Theme', 'Sorting', 'Steam', 'IGDB', 'Done']) {
      expect(find.text(step), findsWidgets, reason: step);
    }
    expect(find.byKey(const Key('step-0-circle')), findsOneWidget);
    expect(find.byKey(const Key('step-4-circle')), findsOneWidget);
    expect(find.text('Skip setup'), findsOneWidget);
  });

  group('the theme step', () {
    testWidgets('lists the themes and applies a choice at once', (
      tester,
    ) async {
      final app = await pumpSetup(tester);
      expect(find.text('Shelf OLED'), findsWidgets);

      await tester.tap(find.byKey(const Key('select-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light').last);
      await tester.pumpAndSettle();

      expect(app.container.read(themeIdProvider), 'light');
      final tokens = Theme.of(
        tester.element(find.byKey(const Key('page-setup'))),
      ).extension<ShelfTokens>()!;
      expect(tokens.background, const Color(0xFFF5F4EF));
    });

    testWidgets('saves the theme with Next and goes on to sorting', (
      tester,
    ) async {
      final app = await pumpSetup(tester);

      await next(tester);

      expect(app.users.updates.single.theme, 'shelfOled');
      expect(find.text('Default sort'), findsOneWidget);
    });
  });

  testWidgets('the sorting step saves the chosen default sort', (tester) async {
    final app = await pumpSetup(tester);
    await next(tester);

    await tester.tap(find.byKey(const Key('select-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playtime').last);
    await tester.pumpAndSettle();
    await next(tester);

    expect(app.users.updates.last.defaultSort, 'playtime');
  });

  group('the Steam step', () {
    Future<Harness> toSteam(WidgetTester tester) async {
      final app = await pumpSetup(tester);
      await next(tester);
      await next(tester);
      return app;
    }

    testWidgets('explains the step and has the two optional fields', (
      tester,
    ) async {
      await toSteam(tester);

      expect(find.text('Connect Steam'), findsOneWidget);
      expect(find.text('OPTIONAL'), findsOneWidget);
      expect(find.text('Steam ID'), findsOneWidget);
      expect(find.text('Web API key'), findsOneWidget);
      final key = find.descendant(
        of: find.byType(Column),
        matching: find.byType(TextField),
      );
      expect(key, findsNWidgets(2));
    });

    testWidgets('opens SteamDB and the API key page from the hint', (
      tester,
    ) async {
      final app = await toSteam(tester);

      await tester.tapAt(centerOfText(tester, "SteamDB's SteamID finder"));
      await tester.tapAt(centerOfText(tester, "Steam's API key page"));

      expect(app.opened, [
        Uri.parse('https://steamdb.com/en/tools/steam-id-finder'),
        Uri.parse('https://steamcommunity.com/dev/apikey'),
      ]);
    });

    testWidgets('saves what was entered', (tester) async {
      final app = await toSteam(tester);

      await tester.enterText(find.byType(TextField).first, '76561197960287930');
      await tester.enterText(find.byType(TextField).last, 'secret-key');
      await next(tester);

      expect(app.users.updates.last.steamId, '76561197960287930');
      expect(app.users.updates.last.steamApiKey, 'secret-key');
    });
  });

  group('the IGDB step', () {
    Future<Harness> toIgdb(WidgetTester tester) async {
      final app = await pumpSetup(tester);
      for (var i = 0; i < 3; i++) {
        await next(tester);
      }
      return app;
    }

    testWidgets('refuses one field without the other', (tester) async {
      await toIgdb(tester);

      await tester.enterText(find.byType(TextField).first, 'client');
      await next(tester);

      expect(
        find.text(
          'Enter both the IGDB Client ID and Client Secret, or neither',
        ),
        findsOneWidget,
      );
      expect(find.text('Connect IGDB'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('opens the Twitch console from the hint', (tester) async {
      final app = await toIgdb(tester);

      await tester.tapAt(centerOfText(tester, 'dev.twitch.tv/console/apps'));

      expect(app.opened, [Uri.parse('https://dev.twitch.tv/console/apps')]);
    });
  });

  group('the last step', () {
    Future<Harness> toDone(WidgetTester tester) async {
      final app = await pumpSetup(tester);
      for (var i = 0; i < 4; i++) {
        await next(tester);
      }
      return app;
    }

    testWidgets(
      'says that two-factor and Discord alerts live in the settings',
      (tester) async {
        await toDone(tester);

        expect(find.text('All set'), findsOneWidget);
        expect(find.textContaining('two-factor'), findsOneWidget);
        expect(find.textContaining('Discord'), findsOneWidget);
        expect(find.text('Skip setup'), findsNothing);
      },
    );

    testWidgets('finishes and goes to Home', (tester) async {
      final app = await toDone(tester);

      await next(tester);

      expect(app.users.updates.last.setupCompleted, isTrue);
      expect(app.location, AppRoutes.home);
      expect(find.byKey(const Key('sidebar')), findsOneWidget);
    });
  });

  testWidgets('skipping from the first step completes the setup', (
    tester,
  ) async {
    final app = await pumpSetup(tester);

    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(app.users.updates.single.setupCompleted, isTrue);
    expect(app.location, AppRoutes.home);
  });

  testWidgets('Back is off on the first step and goes back on the next ones', (
    tester,
  ) async {
    await pumpSetup(tester);
    Opacity back() => tester.widget<Opacity>(
      find
          .descendant(
            of: find.byKey(const Key('setup-back')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(back().opacity, 0.4);

    await next(tester);
    expect(back().opacity, 1);

    await tester.tap(find.byKey(const Key('setup-back')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a look'), findsOneWidget);
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the Steam step in $themeId', tags: 'golden', (
      tester,
    ) async {
      final app = await pumpSetup(tester);
      app.container.read(themeIdProvider.notifier).select(themeId);
      await tester.pumpAndSettle();
      await next(tester);
      await next(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/setup_steam_$themeId.png'),
      );
    });
  }

  testWidgets('a failed save shows a toast and stays on the step', (
    tester,
  ) async {
    final app = await pumpSetup(tester);
    app.users.onUpdate = (_) async =>
        throw const ApiException('Server unavailable');

    await tester.tap(find.byKey(const Key('setup-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Server unavailable'), findsOneWidget);
    expect(find.text('Choose a look'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}

/// The centre on screen of the first occurrence of [text] in a paragraph.
Offset centerOfText(WidgetTester tester, String text) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final index = paragraph.text.toPlainText().indexOf(text);
    if (index == -1) continue;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: index, extentOffset: index + text.length),
    );
    return paragraph.localToGlobal(boxes.first.toRect().center);
  }
  throw StateError('No paragraph contains "$text"');
}
