import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/domain/game_search.dart';
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

  /// The games for a search term (`GET /api/games/enriched-search`); [deep]
  /// also tries other spellings and bundles.
  Future<List<GameSearchResult>> search(String term, {bool deep = false});

  /// The Steam App ID of the game with this title, if Steam has one
  /// (`GET /api/games/steam-app-id`).
  Future<int?> steamAppId(String title);

  /// The covers SteamGridDB has for a Steam App ID.
  Future<List<String>> steamGridDbCovers(int steamAppId);

  /// The games SteamGridDB finds for a search term.
  Future<List<SteamGridDbMatch>> steamGridDbSearch(String term);

  /// The covers of a game found on SteamGridDB.
  Future<List<String>> steamGridDbCoversById(int gameId);
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

  @override
  Future<List<GameSearchResult>> search(
    String term, {
    bool deep = false,
  }) async {
    final results = await (await _client())
        .apiGamesEnrichedSearchEnrichedSearch(searchTerm: term, deep: deep);
    return results.map(gameSearchResultFromResponse).toList();
  }

  @override
  Future<int?> steamAppId(String title) async {
    return (await _client()).apiGamesSteamAppIdGetSteamAppId(title: title);
  }

  @override
  Future<List<String>> steamGridDbCovers(int steamAppId) async {
    return (await _client()).apiGamesSteamgriddbCoversGetSteamgriddbCovers(
      steamAppId: steamAppId,
    );
  }

  @override
  Future<List<SteamGridDbMatch>> steamGridDbSearch(String term) async {
    final matches = await (await _client())
        .apiGamesSteamgriddbSearchSearchSteamgriddb(searchTerm: term);
    return matches.map(steamGridDbMatchFromResponse).toList();
  }

  @override
  Future<List<String>> steamGridDbCoversById(int gameId) async {
    return (await _client())
        .apiGamesSteamgriddbCoversByIdGetSteamgriddbCoversById(gameId: gameId);
  }
}

final gamesApiProvider = Provider<GamesApi>(
  (ref) => ApiGamesApi(() => ref.read(apiDioProvider.future)),
);
