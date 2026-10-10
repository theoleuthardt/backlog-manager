import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/domain/price_listings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The price lookups of the server.
abstract interface class GamesApi {
  /// The CheapShark deals of a Steam game
  /// (`GET /api/games/{steam_app_id}/price`).
  Future<PriceInfo> price(int steamAppId);

  /// The offers of the key shops for a title
  /// (`GET /api/games/key-shop-prices`).
  Future<List<KeyShopOffer>> keyShopPrices(String title);
}

class ApiGamesApi implements GamesApi {
  const ApiGamesApi(this._dio);

  final Future<Dio> Function() _dio;

  Future<wire.FallbackClient> _client() async =>
      wire.RestClient(await _dio()).fallback;

  @override
  Future<PriceInfo> price(int steamAppId) async {
    final response = await (await _client())
        .apiGamesSteamAppIdPriceGetGamePrice(steamAppId: steamAppId);
    return priceInfoFromResponse(response);
  }

  @override
  Future<List<KeyShopOffer>> keyShopPrices(String title) async {
    final offers = await (await _client())
        .apiGamesKeyShopPricesGetKeyShopPrices(title: title);
    return offers.map(keyShopOfferFromResponse).toList();
  }
}

final gamesApiProvider = Provider<GamesApi>(
  (ref) => ApiGamesApi(() => ref.read(apiDioProvider.future)),
);
