import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/auth/session_user_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

PublicUser user({
  String? steamId,
  String? defaultSort,
  Map<String, Object?> extra = const {},
}) => PublicUser.fromJson({
  'id': 1,
  'name': 'Theo',
  'email': 'theo@example.com',
  'is_admin': false,
  'is_two_factor_enabled': false,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
  'setup_completed': true,
  'steam_id': ?steamId,
  'default_sort': ?defaultSort,
  ...extra,
});

void main() {
  test('maps name, email and the setup flag', () {
    final mapped = sessionUserFrom(user());

    expect(mapped.name, 'Theo');
    expect(mapped.email, 'theo@example.com');
    expect(mapped.setupCompleted, isTrue);
  });

  test('carries the default sort of the account', () {
    expect(
      sessionUserFrom(user(defaultSort: 'playtime')).defaultSort,
      'playtime',
    );
    expect(sessionUserFrom(user()).defaultSort, 'status');
  });

  test('keeps the Steam ID, which the settings show', () {
    expect(sessionUserFrom(user(steamId: '7656119')).steamId, '7656119');
    expect(sessionUserFrom(user(steamId: '7656119')).hasSteamId, isTrue);
    expect(sessionUserFrom(user(steamId: '')).hasSteamId, isFalse);
    expect(sessionUserFrom(user()).steamId, '');
    expect(sessionUserFrom(user()).hasSteamId, isFalse);
  });

  test('knows which secrets are set, without keeping them', () {
    final mapped = sessionUserFrom(
      user(
        extra: {
          'has_steam_api_key': true,
          'has_igdb_credentials': true,
          'has_steamgriddb_api_key': true,
          'has_discord_webhook_url': true,
        },
      ),
    );

    expect(mapped.hasSteamApiKey, isTrue);
    expect(mapped.hasIgdbCredentials, isTrue);
    expect(mapped.hasSteamgriddbApiKey, isTrue);
    expect(mapped.hasDiscordWebhookUrl, isTrue);
    final plain = sessionUserFrom(user());
    expect(plain.hasSteamApiKey, isFalse);
    expect(plain.hasIgdbCredentials, isFalse);
    expect(plain.hasSteamgriddbApiKey, isFalse);
    expect(plain.hasDiscordWebhookUrl, isFalse);
  });

  test('knows whether two-factor authentication is on', () {
    expect(
      sessionUserFrom(user(extra: {'is_two_factor_enabled': true}))
          .isTwoFactorEnabled,
      isTrue,
    );
    expect(sessionUserFrom(user()).isTwoFactorEnabled, isFalse);
  });

  test('carries the family IDs and the wishlist sync settings', () {
    final mapped = sessionUserFrom(
      user(
        extra: {
          'steam_family_ids': '7656119, 7656120',
          'steam_wishlist_auto_sync': true,
          'steam_wishlist_imported_at': '2026-10-10T11:37:00',
        },
      ),
    );

    expect(mapped.steamFamilyIds, '7656119, 7656120');
    expect(mapped.steamWishlistAutoSync, isTrue);
    expect(mapped.steamWishlistImportedAt, isNotNull);
    final plain = sessionUserFrom(user());
    expect(plain.steamFamilyIds, '');
    expect(plain.steamWishlistAutoSync, isFalse);
    expect(plain.steamWishlistImportedAt, isNull);
  });
}
