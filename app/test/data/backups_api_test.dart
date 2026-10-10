import 'dart:convert';
import 'dart:typed_data';

import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/data/backups_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/api_client_test.dart' show FakeServer;

ApiBackupsApi apiFor(FakeServer server) {
  final dio = createApiDio(
    baseUrl: 'https://api.test',
    readToken: () async => 'jwt',
    onUnauthorized: () {},
    adapter: server,
  );
  return ApiBackupsApi(() async => dio);
}

Map<String, Object?> backupJson(int id, {String? name}) => {
  'id': id,
  'kind': 'manual',
  'name': ?name,
  'created_at': '2026-10-09T08:07:06',
  'entry_count': 148,
  'category_count': 3,
};

void main() {
  test('lists the backups and reads their time as UTC', () async {
    final server = FakeServer(
      (_) => (
        status: 200,
        body: [
          backupJson(2, name: 'Mine'),
          backupJson(1),
        ],
      ),
    );

    final backups = await apiFor(server).list();

    expect(backups.map((b) => b.id), [2, 1]);
    expect(backups.first.name, 'Mine');
    expect(backups.last.name, isNull);
    expect(backups.first.createdAt.isUtc, isTrue);
    expect(backups.first.createdAt.hour, 8);
    expect(backups.first.entryCount, 148);
    expect(server.requests.single.path, '/api/backups');
  });

  test('creates a backup without a name', () async {
    final server = FakeServer((_) => (status: 200, body: backupJson(7)));

    final backup = await apiFor(server).create();

    expect(backup.id, 7);
    expect(server.requests.single.method, 'POST');
    expect(server.requests.single.path, '/api/backups');
  });

  test('renames a backup, and an empty name clears it', () async {
    final server = FakeServer((_) => (status: 200, body: backupJson(7)));

    await apiFor(server).rename(7, 'Before the move');
    await apiFor(server).rename(7, null);

    expect(server.requests.first.method, 'PUT');
    expect(server.requests.first.path, '/api/backups/7');
    expect(server.requests.first.data, {'name': 'Before the move'});
    expect(server.requests.last.data, {'name': null});
  });

  test('restores a backup and reads what came back', () async {
    final server = FakeServer(
      (_) => (
        status: 200,
        body: {'entry_count': 148, 'category_count': 3, 'safety_backup_id': 9},
      ),
    );

    final result = await apiFor(server).restore(4);

    expect(result.entryCount, 148);
    expect(result.categoryCount, 3);
    expect(result.safetyBackupId, 9);
    expect(server.requests.single.method, 'POST');
    expect(server.requests.single.path, '/api/backups/4/restore');
  });

  test('deletes a backup', () async {
    final server = FakeServer((_) => (status: 204, body: null));

    await apiFor(server).delete(4);

    expect(server.requests.single.method, 'DELETE');
    expect(server.requests.single.path, '/api/backups/4');
  });

  test('downloads a backup as bytes', () async {
    final server = FakeServer(
      (_) => (status: 200, body: {'entries': <Object?>[]}),
    );

    final bytes = await apiFor(server).download(4);

    expect(server.requests.single.path, '/api/backups/4/download');
    expect(jsonDecode(utf8.decode(bytes)), {'entries': <Object?>[]});
    expect(bytes, isA<Uint8List>());
  });
}
