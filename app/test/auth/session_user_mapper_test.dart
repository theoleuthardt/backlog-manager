import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/auth/session_user_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

PublicUser user({String? steamId, String? defaultSort}) => PublicUser.fromJson({
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

  test('knows whether a Steam ID is set, without keeping it', () {
    expect(sessionUserFrom(user(steamId: '7656119')).hasSteamId, isTrue);
    expect(sessionUserFrom(user(steamId: '')).hasSteamId, isFalse);
    expect(sessionUserFrom(user()).hasSteamId, isFalse);
  });
}
