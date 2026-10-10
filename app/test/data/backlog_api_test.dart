import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/api_auth_api_test.dart' show FakeServer;

Map<String, Object?> entryJson(
  int id, {
  String status = 'Not Started',
  String? playtime,
}) => {
  'id': id,
  'title': 'Game $id',
  'genre': ['RPG'],
  'platform': ['PC'],
  'status': status,
  'owned': true,
  'interest': 3,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-02T00:00:00Z',
  'playtime': ?playtime,
};

ApiBacklogApi apiFor(FakeServer server) {
  final dio = createApiDio(
    baseUrl: 'https://api.test',
    readToken: () async => 'jwt',
    onUnauthorized: () {},
    adapter: server,
  );
  return ApiBacklogApi(() async => dio);
}

void main() {
  group('EntryUpdate', () {
    test(
      'only contains the fields that were set, with the names of the backend',
      () {
        expect(const EntryUpdate(status: 'Completed').toJson(), {
          'status': 'Completed',
        });
        expect(
          const EntryUpdate(
            status: 'Playing',
            playtime: 4.5,
            interest: 7,
            reviewStars: 9,
            review: 'good',
            note: 'n',
            owned: false,
            genre: ['RPG', 'Indie'],
            platform: ['PC'],
            imageLink: 'https://x/y.png',
          ).toJson(),
          {
            'status': 'Playing',
            'playtime': 4.5,
            'interest': 7,
            'review_stars': 9,
            'review': 'good',
            'note': 'n',
            'owned': false,
            'genre': ['RPG', 'Indie'],
            'platform': ['PC'],
            'image_link': 'https://x/y.png',
          },
        );
        expect(const EntryUpdate().toJson(), isEmpty);
      },
    );

    test('carries the data of another game with the names of the backend', () {
      expect(
        const EntryUpdate(
          title: 'Hades',
          description: 'Defy the god of the dead.',
          trailerLink: 'https://www.youtube.com/watch?v=abcdefghijk',
          mainTime: 22,
          mainPlusExtraTime: 48,
          completionTime: 95,
          clearSteamAppId: true,
        ).toJson(),
        {
          'title': 'Hades',
          'description': 'Defy the god of the dead.',
          'trailer_link': 'https://www.youtube.com/watch?v=abcdefghijk',
          'main_time': 22,
          'main_plus_extra_time': 48,
          'completion_time': 95,
          'steam_app_id': null,
        },
      );
    });

    test('leaves the Steam App ID alone unless it is to be cleared', () {
      expect(
        const EntryUpdate(status: 'Playing').toJson(),
        isNot(contains('steam_app_id')),
      );
    });

    test('is built from the data of the right game', () {
      final update = EntryUpdate.wrongGame(
        const WrongGameChanges(
          title: 'Hades',
          genre: ['Roguelike'],
          imageLink: 'https://img.example/h.jpg',
          description: 'd',
          trailerLink: null,
          mainTime: 22,
          mainPlusExtraTime: 48,
          completionTime: 95,
        ),
      );

      expect(update.toJson(), {
        'title': 'Hades',
        'genre': ['Roguelike'],
        'image_link': 'https://img.example/h.jpg',
        'description': 'd',
        'main_time': 22,
        'main_plus_extra_time': 48,
        'completion_time': 95,
        'steam_app_id': null,
      });
    });
  });

  group('ApiBacklogApi', () {
    test('lists the entries of the personal backlog without a space', () async {
      final server = FakeServer(
        (_) => (status: 200, body: [entryJson(1), entryJson(2)]),
      );

      final entries = await apiFor(server).entries(null);

      expect(entries.map((e) => e.id), [1, 2]);
      expect(server.requests.single.path, '/api/backlog/entries');
      expect(server.requests.single.queryParameters, isEmpty);
    });

    test('lists the entries of a shared space', () async {
      final server = FakeServer((_) => (status: 200, body: [entryJson(1)]));

      await apiFor(server).entries(7);

      expect(server.requests.single.queryParameters, {'space_id': 7});
    });

    test('maps the decimal strings of an entry to numbers', () async {
      final server = FakeServer(
        (_) => (status: 200, body: [entryJson(1, playtime: '12.50')]),
      );

      final entries = await apiFor(server).entries(null);

      expect(entries.single.playtime, 12.5);
    });

    test('puts only the changed fields of an entry', () async {
      final server = FakeServer(
        (_) => (status: 200, body: entryJson(5, status: 'Completed')),
      );

      final entry = await apiFor(server)
          .updateEntry(5, const EntryUpdate(status: 'Completed'), 3);

      expect(entry.status, 'Completed');
      final request = server.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/backlog/entries/5');
      expect(request.queryParameters, {'space_id': 3});
      expect(request.data, {'status': 'Completed'});
    });

    test('deletes an entry', () async {
      final server = FakeServer((_) => (status: 204, body: null));

      await apiFor(server).deleteEntry(5, null);

      expect(server.requests.single.method, 'DELETE');
      expect(server.requests.single.path, '/api/backlog/entries/5');
    });

    test('lists the custom statuses and the categories', () async {
      final statuses = FakeServer(
        (_) => (
          status: 200,
          body: [
            {'id': 1, 'name': 'Replaying'},
          ],
        ),
      );
      expect(
        (await apiFor(statuses).customStatuses(null)).single.name,
        'Replaying',
      );

      final categories = FakeServer(
        (_) => (
          status: 200,
          body: [
            {'id': 2, 'name': 'Co-op', 'color': '#38bdf8', 'description': null},
          ],
        ),
      );
      final result = await apiFor(categories).categories(null);
      expect(result.single.name, 'Co-op');
      expect(result.single.color, '#38bdf8');
    });

    test('creates a custom status in a space', () async {
      final server = FakeServer(
        (_) => (status: 201, body: {'id': 7, 'name': 'Replaying'}),
      );

      final created = await apiFor(server).createCustomStatus('Replaying', 3);

      expect(created.id, 7);
      expect(created.name, 'Replaying');
      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/backlog/statuses');
      expect(request.queryParameters, {'space_id': 3});
      expect(request.data, {'name': 'Replaying'});
    });

    test('deletes a custom status', () async {
      final server = FakeServer((_) => (status: 204, body: null));

      await apiFor(server).deleteCustomStatus(7, null);

      expect(server.requests.single.method, 'DELETE');
      expect(server.requests.single.path, '/api/backlog/statuses/7');
    });

    test('creates a category with its colour', () async {
      final server = FakeServer(
        (_) => (
          status: 201,
          body: {
            'id': 8,
            'name': 'Co-op nights',
            'color': '#4ade80',
            'description': null,
          },
        ),
      );

      final created = await apiFor(server)
          .createCategory('Co-op nights', '#4ade80', 2);

      expect(created.id, 8);
      expect(created.color, '#4ade80');
      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/backlog/categories');
      expect(request.queryParameters, {'space_id': 2});
      expect(request.data, {
        'category_name': 'Co-op nights',
        'color': '#4ade80',
        'description': 'No description',
      });
    });

    test('updates only the fields that are given', () async {
      final server = FakeServer(
        (_) => (
          status: 200,
          body: {
            'id': 8,
            'name': 'Renamed',
            'color': '#4ade80',
            'description': null,
          },
        ),
      );

      final renamed = await apiFor(server)
          .updateCategory(8, null, name: 'Renamed');
      await apiFor(server).updateCategory(8, null, color: '#f87171');

      expect(renamed.name, 'Renamed');
      expect(server.requests.first.method, 'PUT');
      expect(server.requests.first.path, '/api/backlog/categories/8');
      expect(server.requests.first.data, {'category_name': 'Renamed'});
      expect(server.requests.last.data, {'color': '#f87171'});
    });

    test('deletes a category', () async {
      final server = FakeServer((_) => (status: 204, body: null));

      await apiFor(server).deleteCategory(8, null);

      expect(server.requests.single.method, 'DELETE');
      expect(server.requests.single.path, '/api/backlog/categories/8');
    });

    test('adds and removes a category of an entry', () async {
      final server = FakeServer((_) => (status: 204, body: null));
      final api = apiFor(server);

      await api.setEntryCategory(5, 8, null, assigned: true);
      await api.setEntryCategory(5, 8, 3, assigned: false);

      expect(server.requests.first.method, 'POST');
      expect(server.requests.first.path, '/api/backlog/entries/5/categories/8');
      expect(server.requests.last.method, 'DELETE');
      expect(server.requests.last.path, '/api/backlog/entries/5/categories/8');
      expect(server.requests.last.queryParameters, {'space_id': 3});
    });

    test('lists the entries of a category', () async {
      final server = FakeServer((_) => (status: 200, body: [entryJson(9)]));

      final entries = await apiFor(server).entriesOfCategory(4, null);

      expect(entries.single.id, 9);
      expect(server.requests.single.path, '/api/backlog/categories/4/entries');
    });

    test('reads the achievements of a Steam game', () async {
      final server = FakeServer(
        (_) => (
          status: 200,
          body: {'unlocked': 3, 'total': 15, 'achievements': <Object?>[]},
        ),
      );

      final progress = await apiFor(server).achievements(1145360);

      expect((progress.unlocked, progress.total), (3, 15));
      expect(server.requests.single.queryParameters, {'steam_app_id': 1145360});
    });

    test('asks for the duplicates of a title and a Steam App ID', () async {
      final server = FakeServer((_) => (status: 200, body: [entryJson(4)]));

      final found = await apiFor(server).duplicates('Hades', 1145360, null);

      expect(found.map((e) => e.id), [4]);
      expect(server.requests.single.path, '/api/backlog/entries/duplicates');
      expect(server.requests.single.queryParameters, {
        'title': 'Hades',
        'steam_app_id': 1145360,
      });
    });

    test('reads the Steam playtime as hours', () async {
      final server = FakeServer((_) => (status: 200, body: '12.5'));

      final hours = await apiFor(server).steamPlaytime(620);

      expect(hours, 12.5);
      expect(server.requests.single.path, '/api/user/steam/playtime');
      expect(server.requests.single.queryParameters, {'steam_app_id': 620});
    });

    test('reads a Steam playtime that came as a plain number', () async {
      final server = FakeServer((_) => (status: 200, body: 3));

      expect(await apiFor(server).steamPlaytime(620), 3);
    });

    test('reads no Steam playtime when the account has none', () async {
      final server = FakeServer((_) => (status: 200, body: null));

      expect(await apiFor(server).steamPlaytime(620), isNull);
    });
  });
}
