import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/domain/steam_sync.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Steam import and sync of the signed-in user.
abstract interface class SteamApi {
  /// The owned games that are not in the backlog yet: progress messages, then
  /// `done` with the rows or `error`.
  Stream<SseEvent> libraryPreview();

  /// The games of the public wishlist that are not in the backlog yet.
  Future<List<SteamRow>> wishlistPreview();

  /// Creates entries for the given Steam App IDs: progress messages, then
  /// `done` with the created entries or `error`.
  Stream<SseEvent> importLibrary(List<int> appIds);

  Stream<SseEvent> importWishlist(List<int> appIds);

  /// Brings the playtimes of the entries up to date: progress messages, then
  /// `done` with the updated entries or `error`.
  Stream<SseEvent> syncPlaytimes();
}

class ApiSteamApi implements SteamApi {
  const ApiSteamApi(this._dio);

  final Future<Dio> Function() _dio;

  Stream<SseEvent> _stream(String path, {Object? data}) async* {
    yield* openSse(await _dio(), path, data: data);
  }

  List<Map<String, int>> _items(List<int> appIds) => [
    for (final id in appIds) {'appid': id},
  ];

  @override
  Stream<SseEvent> libraryPreview() =>
      _stream('/api/user/steam/library/preview/stream');

  @override
  Future<List<SteamRow>> wishlistPreview() async {
    final items = await wire.RestClient(await _dio()).fallback
        .apiUserSteamWishlistPreviewPreviewSteamWishlist();
    return [
      for (final item in items)
        SteamRow(
          steamAppId: item.steamAppId,
          title: item.title,
          imageLink: item.imageLink,
        ),
    ];
  }

  @override
  Stream<SseEvent> importLibrary(List<int> appIds) =>
      _stream('/api/user/steam/import/stream', data: _items(appIds));

  @override
  Stream<SseEvent> importWishlist(List<int> appIds) =>
      _stream('/api/user/steam/wishlist/import/stream', data: _items(appIds));

  @override
  Stream<SseEvent> syncPlaytimes() => _stream('/api/user/steam/sync/stream');
}

final steamApiProvider = Provider<SteamApi>(
  (ref) => ApiSteamApi(() => ref.read(apiDioProvider.future)),
);
