// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'game_price.g.dart';

@JsonSerializable()
class GamePrice {
  const GamePrice({
    required this.steamAppId,
    required this.checkedAt,
    this.currency,
    this.currentRetail,
    this.currentKeyshops,
    this.historicalRetail,
    this.historicalKeyshops,
    this.url,
  });

  factory GamePrice.fromJson(Map<String, Object?> json) =>
      _$GamePriceFromJson(json);

  @JsonKey(name: 'steam_app_id')
  final int steamAppId;
  @JsonKey(name: 'checked_at')
  final DateTime checkedAt;
  final String? currency;
  @JsonKey(name: 'current_retail')
  final String? currentRetail;
  @JsonKey(name: 'current_keyshops')
  final String? currentKeyshops;
  @JsonKey(name: 'historical_retail')
  final String? historicalRetail;
  @JsonKey(name: 'historical_keyshops')
  final String? historicalKeyshops;
  final String? url;

  Map<String, Object?> toJson() => _$GamePriceToJson(this);
}
