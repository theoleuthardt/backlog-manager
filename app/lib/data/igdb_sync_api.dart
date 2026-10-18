import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The retroactive IGDB sync of the signed-in user: of the personal backlog
/// or, with a `spaceId`, of the Shared Space.
abstract interface class IgdbSyncApi {
  /// How many games the sync would look up.
  Future<int> pendingCount({int? spaceId});

  /// Runs the sync: progress messages, then `done` with the updated games or
  /// `error`. Cancelling the subscription stops it on the server.
  Stream<SseEvent> sync({int? spaceId});
}

class ApiIgdbSyncApi implements IgdbSyncApi {
  const ApiIgdbSyncApi(this._dio);

  final Future<Dio> Function() _dio;

  @override
  Future<int> pendingCount({int? spaceId}) async {
    final dio = await _dio();
    return wire.RestClient(dio).fallback
        .apiIgdbSyncPendingCountGetPendingCount(spaceId: spaceId);
  }

  @override
  Stream<SseEvent> sync({int? spaceId}) async* {
    yield* openSse(
      await _dio(),
      '/api/igdb-sync/stream',
      queryParameters: {'space_id': ?spaceId},
    );
  }
}

final igdbSyncApiProvider = Provider<IgdbSyncApi>(
  (ref) => ApiIgdbSyncApi(() => ref.read(apiDioProvider.future)),
);

/// How many games the sync would look up in the backlog `spaceId` (null: the
/// personal one); read again whenever the sheet opens.
final igdbPendingCountProvider = FutureProvider.autoDispose.family<int, int?>((
  ref,
  spaceId,
) {
  ref.watch(sessionGenerationProvider);
  return ref.watch(igdbSyncApiProvider).pendingCount(spaceId: spaceId);
});
