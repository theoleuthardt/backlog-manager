// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_price.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GamePrice _$GamePriceFromJson(Map<String, dynamic> json) => GamePrice(
  steamAppId: (json['steam_app_id'] as num).toInt(),
  checkedAt: DateTime.parse(json['checked_at'] as String),
  currency: json['currency'] as String?,
  currentRetail: json['current_retail'] as String?,
  currentKeyshops: json['current_keyshops'] as String?,
  historicalRetail: json['historical_retail'] as String?,
  historicalKeyshops: json['historical_keyshops'] as String?,
  url: json['url'] as String?,
);

Map<String, dynamic> _$GamePriceToJson(GamePrice instance) => <String, dynamic>{
  'steam_app_id': instance.steamAppId,
  'checked_at': instance.checkedAt.toIso8601String(),
  'currency': instance.currency,
  'current_retail': instance.currentRetail,
  'current_keyshops': instance.currentKeyshops,
  'historical_retail': instance.historicalRetail,
  'historical_keyshops': instance.historicalKeyshops,
  'url': instance.url,
};
