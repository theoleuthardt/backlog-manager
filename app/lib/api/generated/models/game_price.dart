// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'game_price_deal.dart';

part 'game_price.g.dart';

@JsonSerializable()
class GamePrice {
  const GamePrice({
    required this.steamAppId,
    required this.deals,
    required this.onSale,
    required this.checkedAt,
    this.cheapsharkGameId,
    this.cheapestPriceEver,
    this.cheapestPriceEverDate,
  });

  factory GamePrice.fromJson(Map<String, Object?> json) =>
      _$GamePriceFromJson(json);

  @JsonKey(name: 'steam_app_id')
  final int steamAppId;
  final List<GamePriceDeal> deals;
  @JsonKey(name: 'on_sale')
  final bool onSale;
  @JsonKey(name: 'checked_at')
  final DateTime checkedAt;
  @JsonKey(name: 'cheapshark_game_id')
  final int? cheapsharkGameId;
  @JsonKey(name: 'cheapest_price_ever')
  final String? cheapestPriceEver;
  @JsonKey(name: 'cheapest_price_ever_date')
  final DateTime? cheapestPriceEverDate;

  Map<String, Object?> toJson() => _$GamePriceToJson(this);
}
