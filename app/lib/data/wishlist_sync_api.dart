import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/domain/wishlist_sync_report.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The report of the automatic Steam wishlist sync.
abstract interface class WishlistSyncApi {
  Future<WishlistSyncReport> report();

  /// Clears the report on the server once the user has seen it.
  Future<void> dismiss();
}

class ApiWishlistSyncApi implements WishlistSyncApi {
  const ApiWishlistSyncApi(this._dio);

  final Future<Dio> Function() _dio;

  Future<wire.FallbackClient> _client() async =>
      wire.RestClient(await _dio()).fallback;

  @override
  Future<WishlistSyncReport> report() async {
    final report = await (await _client())
        .apiUserSteamWishlistSyncReportGetWishlistSyncReport();
    return wishlistSyncReportFromResponse(report);
  }

  @override
  Future<void> dismiss() async {
    await (await _client())
        .apiUserSteamWishlistSyncReportDismissWishlistSyncReport();
  }
}

final wishlistSyncApiProvider = Provider<WishlistSyncApi>(
  (ref) => ApiWishlistSyncApi(() => ref.read(apiDioProvider.future)),
);

/// What the automatic wishlist sync changed since the user last closed the
/// report; read again after every sign-in.
final wishlistSyncReportProvider = FutureProvider<WishlistSyncReport>((ref) {
  ref.watch(sessionGenerationProvider);
  return ref.watch(wishlistSyncApiProvider).report();
});
