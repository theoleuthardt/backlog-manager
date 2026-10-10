import 'dart:typed_data';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/domain/backups.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The backups the server keeps of the backlog of the signed-in user.
abstract interface class BackupsApi {
  Future<List<Backup>> list();

  /// A manual backup without a name.
  Future<Backup> create();

  /// Gives a backup a name, or clears it with null.
  Future<Backup> rename(int id, String? name);

  /// Replaces the backlog with the backup; the server first keeps the current
  /// state as a backup of its own.
  Future<RestoreResult> restore(int id);

  Future<void> delete(int id);

  /// The backup as the JSON file the user can keep.
  Future<Uint8List> download(int id);
}

Backup _backupFrom(wire.BackupSummary backup) {
  return Backup(
    id: backup.id,
    kind: backup.kind,
    name: backup.name,
    createdAt: serverTimeAsUtc(backup.createdAt),
    entryCount: backup.entryCount,
    categoryCount: backup.categoryCount,
  );
}

class ApiBackupsApi implements BackupsApi {
  const ApiBackupsApi(this._dio);

  final Future<Dio> Function() _dio;

  Future<wire.FallbackClient> _client() async =>
      wire.RestClient(await _dio()).fallback;

  @override
  Future<List<Backup>> list() async {
    final backups = await (await _client()).apiBackupsListBackups();
    return backups.map(_backupFrom).toList();
  }

  @override
  Future<Backup> create() async {
    return _backupFrom(await (await _client()).apiBackupsCreateBackup());
  }

  @override
  Future<Backup> rename(int id, String? name) async {
    final backup = await (await _client()).apiBackupsBackupIdRenameBackup(
      backupId: id,
      body: wire.RenameBackupRequest(name: name),
    );
    return _backupFrom(backup);
  }

  @override
  Future<RestoreResult> restore(int id) async {
    final result = await (await _client())
        .apiBackupsBackupIdRestoreRestoreBackup(backupId: id);
    return RestoreResult(
      entryCount: result.entryCount,
      categoryCount: result.categoryCount,
      safetyBackupId: result.safetyBackupId,
    );
  }

  @override
  Future<void> delete(int id) async {
    await (await _client()).apiBackupsBackupIdDeleteBackup(backupId: id);
  }

  @override
  Future<Uint8List> download(int id) async {
    final response = await (await _dio()).get<List<int>>(
      '/api/backups/$id/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}

final backupsApiProvider = Provider<BackupsApi>(
  (ref) => ApiBackupsApi(() => ref.read(apiDioProvider.future)),
);

/// The backups of the user, newest first as the server sends them.
final backupsProvider = FutureProvider<List<Backup>>((ref) {
  ref.watch(sessionGenerationProvider);
  return ref.watch(backupsApiProvider).list();
});
