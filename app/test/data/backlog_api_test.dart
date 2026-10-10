import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/data/backlog_api.dart';
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
  });
}
