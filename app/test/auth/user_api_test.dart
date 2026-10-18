import 'dart:typed_data';

import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/auth/user_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_auth_api_test.dart' show FakeServer, userJson;

ApiUserApi apiFor(FakeServer server) {
  final dio = createApiDio(
    baseUrl: 'https://api.test',
    readToken: () async => 'jwt',
    onUnauthorized: () {},
    adapter: server,
  );
  return ApiUserApi(() async => dio);
}

void main() {
  group('UserUpdate', () {
    test('only contains the fields that were set', () {
      expect(const UserUpdate(defaultSort: 'genre').toJson(), {
        'default_sort': 'genre',
      });
      expect(const UserUpdate().toJson(), isEmpty);
    });

    test('uses the names of the backend', () {
      expect(
        const UserUpdate(
          theme: 'light',
          defaultSort: 'review_stars',
          steamId: '76561197960287930',
          steamApiKey: 'key',
          igdbClientId: 'id',
          igdbClientSecret: 'secret',
          setupCompleted: true,
        ).toJson(),
        {
          'theme': 'light',
          'default_sort': 'review_stars',
          'steam_id': '76561197960287930',
          'steam_api_key': 'key',
          'igdb_client_id': 'id',
          'igdb_client_secret': 'secret',
          'setup_completed': true,
        },
      );
    });

    test('carries the other settings with the names of the backend', () {
      expect(
        const UserUpdate(
          steamFamilyIds: '1, 2',
          steamgriddbApiKey: 'grid',
          discordWebhookUrl: 'https://discord.com/api/webhooks/1/x',
          steamWishlistAutoSync: true,
        ).toJson(),
        {
          'steam_family_ids': '1, 2',
          'steamgriddb_api_key': 'grid',
          'discord_webhook_url': 'https://discord.com/api/webhooks/1/x',
          'steam_wishlist_auto_sync': true,
        },
      );
    });

    test('an empty text is sent, which removes a saved secret', () {
      expect(
        const UserUpdate(
          steamApiKey: '',
          igdbClientId: '',
          igdbClientSecret: '',
          steamgriddbApiKey: '',
          discordWebhookUrl: '',
          steamFamilyIds: '',
        ).toJson(),
        {
          'steam_api_key': '',
          'igdb_client_id': '',
          'igdb_client_secret': '',
          'steamgriddb_api_key': '',
          'discord_webhook_url': '',
          'steam_family_ids': '',
        },
      );
    });

    test('is empty when nothing was set', () {
      expect(const UserUpdate().isEmpty, isTrue);
      expect(const UserUpdate(setupCompleted: false).isEmpty, isFalse);
    });
  });

  group('ApiUserApi.update', () {
    test(
      'puts only the given fields, never a null that would clear another one',
      () async {
        final server = FakeServer((_) => (status: 200, body: userJson()));

        await apiFor(server).update(const UserUpdate(defaultSort: 'genre'));

        final request = server.requests.single;
        expect(request.method, 'PUT');
        expect(request.path, '/api/user/me');
        expect(request.data, {'default_sort': 'genre'});
      },
    );

    test('returns the user as the session sees it', () async {
      final server = FakeServer(
        (_) => (status: 200, body: userJson(setupCompleted: true)),
      );

      final user = await apiFor(server)
          .update(const UserUpdate(setupCompleted: true));

      expect(user.setupCompleted, isTrue);
      expect(user.name, 'Theo');
    });
  });

  group('ApiUserApi profile picture', () {
    final png = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);

    test('puts the raw bytes with their type and returns the user', () async {
      final server = FakeServer(
        (options) => options.method == 'PUT'
            ? (status: 204, body: null)
            : (
                status: 200,
                body: {
                  ...userJson(),
                  'avatar_updated_at': '2026-10-12T10:00:00.123456',
                },
              ),
      );

      final user = await apiFor(server).setAvatar(png, 'image/png');

      final put = server.requests.first;
      expect(put.method, 'PUT');
      expect(put.path, '/api/user/avatar');
      expect(put.contentType, 'image/png');
      expect(put.data, png);
      expect(server.requests.last.path, '/api/user/me');
      expect(user.avatarUpdatedAt, isNotNull);
    });

    test('deletes the picture and returns the user', () async {
      final server = FakeServer(
        (options) => options.method == 'DELETE'
            ? (status: 204, body: null)
            : (status: 200, body: userJson()),
      );

      final user = await apiFor(server).removeAvatar();

      expect(server.requests.first.method, 'DELETE');
      expect(server.requests.first.path, '/api/user/avatar');
      expect(user.avatarUpdatedAt, isNull);
    });

    test('a user without a readable picture is null', () async {
      final server = FakeServer((_) => (status: 404, body: {'detail': 'x'}));

      expect(await apiFor(server).avatar(7), isNull);
      expect(server.requests.single.path, '/api/user/7/avatar');
    });
  });
}
