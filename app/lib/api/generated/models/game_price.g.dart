// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_price.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GamePrice _$GamePriceFromJson(Map<String, dynamic> json) => GamePrice(
  steamAppId: (json['steam_app_id'] as num).toInt(),
  deals: (json['deals'] as List<dynamic>)
      .map((e) => GamePriceDeal.fromJson(e as Map<String, dynamic>))
      .toList(),
  onSale: json['on_sale'] as bool,
  checkedAt: DateTime.parse(json['checked_at'] as String),
  cheapsharkGameId: (json['cheapshark_game_id'] as num?)?.toInt(),
  cheapestPriceEver: json['cheapest_price_ever'] as String?,
  cheapestPriceEverDate: json['cheapest_price_ever_date'] == null
      ? null
      : DateTime.parse(json['cheapest_price_ever_date'] as String),
);

Map<String, dynamic> _$GamePriceToJson(GamePrice instance) => <String, dynamic>{
  'steam_app_id': instance.steamAppId,
  'deals': instance.deals,
  'on_sale': instance.onSale,
  'checked_at': instance.checkedAt.toIso8601String(),
  'cheapshark_game_id': instance.cheapsharkGameId,
  'cheapest_price_ever': instance.cheapestPriceEver,
  'cheapest_price_ever_date': instance.cheapestPriceEverDate?.toIso8601String(),
};
