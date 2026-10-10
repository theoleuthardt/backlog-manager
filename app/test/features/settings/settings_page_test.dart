import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/auth/auth_api.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../auth/fakes.dart';
import '../setup/setup_controller_test.dart' show FakeUserApi;

class SignedInAs extends SessionNotifier {
  SignedInAs(this.user);

  final SessionUser user;

  @override
  SessionState build() => SessionSignedIn(user);
}

SessionUser applied(SessionUser user, UserUpdate update) {
  final json = update.toJson();
  String text(String key, String current) =>
      json.containsKey(key) ? json[key]! as String : current;
  bool has(String key, bool current) =>
      json.containsKey(key) ? (json[key]! as String).isNotEmpty : current;
  return SessionUser(
    name: user.name,
    email: user.email,
    setupCompleted: true,
    defaultSort: text('default_sort', user.defaultSort),
    steamId: text('steam_id', user.steamId),
    steamFamilyIds: text('steam_family_ids', user.steamFamilyIds),
    theme: update.theme ?? user.theme,
    customThemes: update.customThemes ?? user.customThemes,
    hasSteamApiKey: has('steam_api_key', user.hasSteamApiKey),
    hasIgdbCredentials: has('igdb_client_id', user.hasIgdbCredentials),
    hasSteamgriddbApiKey: has('steamgriddb_api_key', user.hasSteamgriddbApiKey),
    hasDiscordWebhookUrl: has('discord_webhook_url', user.hasDiscordWebhookUrl),
    steamWishlistAutoSync: json.containsKey('steam_wishlist_auto_sync')
        ? json['steam_wishlist_auto_sync']! as bool
        : user.steamWishlistAutoSync,
    steamWishlistImportedAt: user.steamWishlistImportedAt,
    isTwoFactorEnabled: user.isTwoFactorEnabled,
  );
}

class Settings {
  Settings(
    this.tester,
    this.users,
    this.opened,
    this.mutateAccount,
    this.failRefreshes,
  );

  /// Makes reading the account fail, like a lost connection.
  final void Function(bool fails) failRefreshes;

  /// Changes the account the fake server holds.
  final void Function(SessionUser Function(SessionUser account)) mutateAccount;

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
      .toString();
}

const theo = SessionUser(
  name: 'Theo',
  email: 'theo@example.com',
  setupCompleted: true,
  steamId: '76561197960287930',
);

Future<Settings> openSettings(
  WidgetTester tester, {
  SessionUser user = theo,
  String location = '/settings',
  Future<void> Function(UserUpdate update)? onUpdate,
  UserUpdate Function(UserUpdate update)? normalize,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var account = user;
  var refreshFails = false;
  final users = FakeUserApi()
    ..onUpdate = (update) async {
      await onUpdate?.call(update);
      account = applied(account, normalize?.call(update) ?? update);
      return account;
    };
  final auth = FakeAuthApi()
    ..onCurrentUser = () async {
      if (refreshFails) throw Exception('offline');
      return account;
    };
  final opened = <Uri>[];

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        sessionProvider.overrideWith(() => SignedInAs(user)),
        userApiProvider.overrideWithValue(users),
        authApiProvider.overrideWithValue(auth),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore('jwt')),
        urlOpenerProvider.overrideWithValue(opened.add),
        appVersionProvider.overrideWith((ref) async => 'v1.2.3'),
        ...overrides,
      ],
      child: const BacklogManagerApp(),
    ),
  );
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(routerProvider).go(location);
  await tester.pumpAndSettle();
  return Settings(
    tester,
    users,
    opened,
    (change) => account = change(account),
    (fails) => refreshFails = fails,
  );
}

String textOf(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

Future<void> commit(WidgetTester tester, Key key, String text) async {
  await tester.enterText(find.byKey(key), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> afterAutosave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

const integrations = '/settings?tab=integrations';

void main() {
  group('the window', () {
    testWidgets('has the tabs and the account at the foot of the list', (
      tester,
    ) async {
      await openSettings(tester);

      expect(find.byKey(const Key('page-settings')), findsOneWidget);
      for (final tab in ['General', 'Integrations', 'About']) {
        expect(find.text(tab), findsWidgets);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-account')),
          matching: find.text('theo@example.com'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('opens the tab named in the address', (tester) async {
      await openSettings(tester, location: integrations);

      expect(find.byKey(const Key('settings-steam-id')), findsOneWidget);
    });

    testWidgets('switches between the tabs', (tester) async {
      await openSettings(tester);

      await tester.tap(find.byKey(const Key('settings-tab-integrations')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-steam-id')), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-tab-about')));
      await tester.pumpAndSettle();
      expect(find.text('v1.2.3'), findsOneWidget);
    });

    testWidgets('says that changes save automatically', (tester) async {
      await openSettings(tester);

      expect(
        find.text('Changes in settings save automatically'),
        findsOneWidget,
      );
    });
  });

  group('General', () {
    testWidgets('shows who is signed in', (tester) async {
      await openSettings(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('settings-name'))).data,
        'Theo',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('settings-email'))).data,
        'theo@example.com',
      );
    });

    testWidgets('saves the default sort when it is chosen', (tester) async {
      final settings = await openSettings(tester);

      await tester.tap(find.byKey(const Key('settings-default-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playtime').last);
      await tester.pumpAndSettle();

      expect(settings.users.updates.single.defaultSort, 'playtime');
      expect(find.text('Default sort saved'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('offers all seven sort options', (tester) async {
      await openSettings(tester);

      await tester.tap(find.byKey(const Key('settings-default-sort')));
      await tester.pumpAndSettle();

      for (final label in [
        'Status',
        'Category',
        'Genre',
        'Playtime',
        'Platform',
        'Interest level',
        'Review stars',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('opens the appearance screen', (tester) async {
      final settings = await openSettings(tester);

      await tester.tap(find.byKey(const Key('settings-appearance')));
      await tester.pumpAndSettle();

      expect(settings.location, '/appearance');
    });
  });

  group('Steam', () {
    testWidgets('shows the saved Steam ID and family IDs', (tester) async {
      await openSettings(
        tester,
        location: integrations,
        user: const SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
          steamId: '76561197960287930',
          steamFamilyIds: '1, 2',
        ),
      );

      expect(
        textOf(tester, const Key('settings-steam-id')),
        '76561197960287930',
      );
      expect(textOf(tester, const Key('settings-family-ids')), '1, 2');
    });

    testWidgets('saves the Steam ID 800 ms after the last key', (tester) async {
      final settings = await openSettings(tester, location: integrations);

      await tester.enterText(
        find.byKey(const Key('settings-steam-id')),
        '76561198000000001',
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(settings.users.updates, isEmpty);
      await afterAutosave(tester);

      expect(settings.users.updates.single.steamId, '76561198000000001');
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('leaving the tab saves what is still waiting', (tester) async {
      final settings = await openSettings(tester, location: integrations);

      await tester.enterText(
        find.byKey(const Key('settings-steam-id')),
        '76561198000000001',
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('settings-tab-about')));
      await tester.pumpAndSettle();

      expect(settings.users.updates.single.steamId, '76561198000000001');
    });

    testWidgets('shows the Steam ID the server holds after a save', (
      tester,
    ) async {
      await openSettings(
        tester,
        location: integrations,
        normalize: (update) => update.steamId == null
            ? update
            : const UserUpdate(steamId: '76561198000000009'),
      );

      await tester.enterText(
        find.byKey(const Key('settings-steam-id')),
        '  7656119800000000  ',
      );
      await afterAutosave(tester);

      expect(
        textOf(tester, const Key('settings-steam-id')),
        '76561198000000009',
      );
    });

    testWidgets('saves nothing when the Steam ID is the same', (tester) async {
      final settings = await openSettings(tester, location: integrations);

      await tester.enterText(
        find.byKey(const Key('settings-steam-id')),
        ' 76561197960287930 ',
      );
      await afterAutosave(tester);

      expect(settings.users.updates, isEmpty);
    });

    testWidgets('saves the family IDs', (tester) async {
      final settings = await openSettings(tester, location: integrations);

      await tester.enterText(
        find.byKey(const Key('settings-family-ids')),
        '1, 2',
      );
      await afterAutosave(tester);

      expect(settings.users.updates.single.steamFamilyIds, '1, 2');
    });

    testWidgets('a saved key is never shown and can be replaced', (
      tester,
    ) async {
      final settings = await openSettings(
        tester,
        location: integrations,
        user: const SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
          hasSteamApiKey: true,
        ),
      );
      expect(textOf(tester, const Key('settings-steam-key')), isEmpty);
      expect(find.text('Enter a new key to replace it'), findsOneWidget);

      await commit(tester, const Key('settings-steam-key'), 'NEWKEY');

      expect(settings.users.updates.single.steamApiKey, 'NEWKEY');
      expect(find.text('Steam API key saved'), findsOneWidget);
      expect(textOf(tester, const Key('settings-steam-key')), isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a key is saved and then can be removed', (tester) async {
      final settings = await openSettings(tester, location: integrations);
      expect(find.byKey(const Key('settings-steam-key-remove')), findsNothing);

      await commit(tester, const Key('settings-steam-key'), 'KEY');
      expect(
        find.byKey(const Key('settings-steam-key-remove')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('settings-steam-key-remove')));
      await tester.pumpAndSettle();

      expect(settings.users.updates.last.steamApiKey, '');
      expect(find.text('Steam API key removed'), findsOneWidget);
      expect(find.byKey(const Key('settings-steam-key-remove')), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('an empty key is not sent', (tester) async {
      final settings = await openSettings(tester, location: integrations);

      await commit(tester, const Key('settings-steam-key'), '   ');

      expect(settings.users.updates, isEmpty);
    });
  });

  group('the wishlist sync', () {
    testWidgets('is off limits before the first wishlist import', (
      tester,
    ) async {
      final settings = await openSettings(tester, location: integrations);
      expect(
        find.textContaining('Available after the first wishlist import'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('settings-wishlist-sync')));
      await tester.pumpAndSettle();

      expect(settings.users.updates, isEmpty);
    });

    testWidgets('is switched on and off after the import', (tester) async {
      final settings = await openSettings(
        tester,
        location: integrations,
        user: SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
          steamWishlistImportedAt: DateTime.utc(2026, 10, 10),
        ),
      );

      await tester.tap(find.byKey(const Key('settings-wishlist-sync')));
      await tester.pumpAndSettle();
      expect(settings.users.updates.single.steamWishlistAutoSync, isTrue);
      expect(
        find.text('Your wishlist is now synced every hour'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 6));
      await tester.tap(find.byKey(const Key('settings-wishlist-sync')));
      await tester.pumpAndSettle();
      expect(settings.users.updates.last.steamWishlistAutoSync, isFalse);
      expect(find.text('Automatic wishlist sync turned off'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('IGDB and SteamGridDB', () {
    testWidgets('IGDB needs both halves before it saves', (tester) async {
      final settings = await openSettings(tester, location: integrations);

      await commit(tester, const Key('settings-igdb-id'), 'client-id');
      expect(settings.users.updates, isEmpty);

      await commit(tester, const Key('settings-igdb-secret'), 'secret');

      final update = settings.users.updates.single;
      expect(update.igdbClientId, 'client-id');
      expect(update.igdbClientSecret, 'secret');
      expect(find.text('IGDB credentials saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('IGDB credentials can be removed', (tester) async {
      final settings = await openSettings(
        tester,
        location: integrations,
        user: const SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
          hasIgdbCredentials: true,
        ),
      );
      expect(textOf(tester, const Key('settings-igdb-secret')), isEmpty);

      await tester.tap(find.byKey(const Key('settings-igdb-remove')));
      await tester.pumpAndSettle();

      final update = settings.users.updates.single;
      expect((update.igdbClientId, update.igdbClientSecret), ('', ''));
      expect(find.text('IGDB credentials removed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('saves and removes the SteamGridDB key', (tester) async {
      final settings = await openSettings(tester, location: integrations);

      await commit(tester, const Key('settings-grid-key'), 'grid');
      expect(settings.users.updates.single.steamgriddbApiKey, 'grid');
      expect(find.text('SteamGridDB API key saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));

      await tester.tap(find.byKey(const Key('settings-grid-remove')));
      await tester.pumpAndSettle();
      expect(settings.users.updates.last.steamgriddbApiKey, '');
      expect(find.text('SteamGridDB API key removed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('Discord', () {
    testWidgets('saves a webhook', (tester) async {
      final settings = await openSettings(tester, location: integrations);

      await commit(
        tester,
        const Key('settings-discord'),
        'https://discord.com/api/webhooks/1/abc',
      );

      expect(
        settings.users.updates.single.discordWebhookUrl,
        'https://discord.com/api/webhooks/1/abc',
      );
      expect(find.text('Discord webhook URL saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('shows the message of the backend when it refuses', (
      tester,
    ) async {
      await openSettings(
        tester,
        location: integrations,
        onUpdate: (update) async =>
            throw const ApiException('Not a Discord webhook URL'),
      );

      await commit(
        tester,
        const Key('settings-discord'),
        'https://evil.example',
      );

      expect(find.text('Not a Discord webhook URL'), findsOneWidget);
      expect(find.text('Not saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('the links', () {
    testWidgets('open in the browser', (tester) async {
      final settings = await openSettings(tester, location: integrations);

      await tester.tapOnText(
        find.textRange.ofSubstring("SteamDB's SteamID finder"),
      );
      await tester.tapOnText(
        find.textRange.ofSubstring("Steam's API key page"),
      );
      await tester.tapOnText(
        find.textRange.ofSubstring('dev.twitch.tv/console/apps'),
      );

      expect(settings.opened, [
        Uri.parse('https://steamdb.com/en/tools/steam-id-finder'),
        Uri.parse('https://steamcommunity.com/dev/apikey'),
        Uri.parse('https://dev.twitch.tv/console/apps'),
      ]);
    });

    testWidgets('About opens the source code', (tester) async {
      final settings = await openSettings(
        tester,
        location: '/settings?tab=about',
      );

      await tester.tap(find.byKey(const Key('settings-source')));
      await tester.pump();

      expect(settings.opened, [
        Uri.parse('https://github.com/theoleuthardt/backlog-manager'),
      ]);
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the integrations in $themeId', tags: 'golden', (
      tester,
    ) async {
      final settings = await openSettings(
        tester,
        location: integrations,
        user: const SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
          steamId: '76561197960287930',
          hasSteamApiKey: true,
        ),
      );
      settings.container.read(themeIdProvider.notifier).select(themeId);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_integrations_$themeId.png'),
      );
    });
  }
}
