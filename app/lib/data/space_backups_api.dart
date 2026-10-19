import 'dart:async';
import 'dart:typed_data';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/domain/backups.dart';
import 'package:backlog_manager/domain/space_backups.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The backups of the Shared Space. Either member can take one, a restore
/// needs both: one asks, the other approves.
abstract interface class SpaceBackupsApi {
  Future<SpaceBackups> list();

  /// A manual backup without a name.
  Future<SpaceBackup> create();

  /// Gives a backup a name, or clears it with null.
  Future<void> rename(int id, String? name);

  /// Asks for the restore of a backup; it runs at once only when the member
  /// is alone in the space.
  Future<SpaceRestoreOutcome> requestRestore(int id);

  /// Lets the restore the partner asked for run.
  Future<RestoreResult> approveRestore();

  /// Takes the open request back, or declines it.
  Future<void> withdrawRestoreRequest();

  Future<void> delete(int id);

  /// The backup as the JSON file the user can keep.
  Future<Uint8List> download(int id);

  /// The current content of the space as a JSON file.
  Future<Uint8List> export();
}

SpaceBackup _backupFrom(wire.SpaceBackupSummary backup) {
  return SpaceBackup(
    id: backup.id,
    kind: backup.kind,
    name: backup.name,
    createdAt: serverTimeAsUtc(backup.createdAt),
    entryCount: backup.entryCount,
    categoryCount: backup.categoryCount,
    createdBy: backup.createdBy,
  );
}

RestoreRequest _requestFrom(wire.RestoreRequestResponse request) {
  return RestoreRequest(
    id: request.id,
    backupId: request.backupId,
    backupName: request.backupName,
    backupCreatedAt: serverTimeAsUtc(request.backupCreatedAt),
    requestedBy: request.requestedBy,
    requestedByMe: request.requestedByMe,
    createdAt: serverTimeAsUtc(request.createdAt),
    expiresAt: serverTimeAsUtc(request.expiresAt),
  );
}

RestoreResult _resultFrom(wire.RestoreResult result) {
  return RestoreResult(
    entryCount: result.entryCount,
    categoryCount: result.categoryCount,
    safetyBackupId: result.safetyBackupId,
  );
}

class ApiSpaceBackupsApi implements SpaceBackupsApi {
  const ApiSpaceBackupsApi(this._dio);

  final Future<Dio> Function() _dio;

  Future<wire.FallbackClient> _client() async =>
      wire.RestClient(await _dio()).fallback;

  @override
  Future<SpaceBackups> list() async {
    final list = await (await _client()).apiSpaceBackupsListSpaceBackups();
    final request = list.restoreRequest;
    return SpaceBackups(
      backups: list.backups.map(_backupFrom).toList(),
      restoreRequest: request == null ? null : _requestFrom(request),
    );
  }

  @override
  Future<SpaceBackup> create() async {
    return _backupFrom(
      await (await _client()).apiSpaceBackupsCreateSpaceBackup(),
    );
  }

  @override
  Future<void> rename(int id, String? name) async {
    await (await _client()).apiSpaceBackupsBackupIdRenameSpaceBackup(
      backupId: id,
      body: wire.RenameBackupRequest(name: name),
    );
  }

  @override
  Future<SpaceRestoreOutcome> requestRestore(int id) async {
    final response = await (await _client())
        .apiSpaceBackupsBackupIdRestoreRestoreSpaceBackup(backupId: id);
    final request = response.request;
    if (response.restored || request == null) {
      return const SpaceRestoreOutcome.restored();
    }
    return SpaceRestoreOutcome.waiting(_requestFrom(request));
  }

  @override
  Future<RestoreResult> approveRestore() async {
    return _resultFrom(
      await (await _client())
          .apiSpaceRestoreRequestApproveApproveSpaceRestore(),
    );
  }

  @override
  Future<void> withdrawRestoreRequest() async {
    await (await _client()).apiSpaceRestoreRequestWithdrawSpaceRestoreRequest();
  }

  @override
  Future<void> delete(int id) async {
    await (await _client()).apiSpaceBackupsBackupIdDeleteSpaceBackup(
      backupId: id,
    );
  }

  Future<Uint8List> _bytes(String path) async {
    final response = await (await _dio()).get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  @override
  Future<Uint8List> download(int id) =>
      _bytes('/api/space/backups/$id/download');

  @override
  Future<Uint8List> export() => _bytes('/api/space/export');
}

final spaceBackupsApiProvider = Provider<SpaceBackupsApi>(
  (ref) => ApiSpaceBackupsApi(() => ref.read(apiDioProvider.future)),
);

/// The space backups, read again every [spaceRefreshInterval] so a restore
/// the partner asked for shows up without a reload. Reading again keeps the
/// old value on screen, a failed read keeps it too.
class SpaceBackupsNotifier extends AsyncNotifier<SpaceBackups> {
  @override
  Future<SpaceBackups> build() async {
    ref.watch(sessionGenerationProvider);
    final timer = Timer.periodic(spaceRefreshInterval, (_) {
      unawaited(refresh());
    });
    ref.onDispose(timer.cancel);
    return ref.watch(spaceBackupsApiProvider).list();
  }

  /// Reads the backups now.
  Future<void> refresh() async {
    try {
      final next = await ref.read(spaceBackupsApiProvider).list();
      if (ref.mounted) state = AsyncData(next);
    } on Object {
      return;
    }
  }
}

final spaceBackupsProvider =
    AsyncNotifierProvider<SpaceBackupsNotifier, SpaceBackups>(
      SpaceBackupsNotifier.new,
    );

/// Whether the partner asked for a restore that waits for the member's
/// approval, for the dot on the Backups button.
final restoreWaitsForMeProvider = Provider<bool>((ref) {
  final request = ref.watch(spaceBackupsProvider).value?.restoreRequest;
  return request != null && !request.requestedByMe;
});
