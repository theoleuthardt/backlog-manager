// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_price_deal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GamePriceDeal _$GamePriceDealFromJson(Map<String, dynamic> json) =>
    GamePriceDeal(
      store: json['store'] as String,
      icon: json['icon'] as String,
      price: json['price'] as num,
      retailPrice: json['retail_price'] as num,
      url: json['url'] as String,
    );

Map<String, dynamic> _$GamePriceDealToJson(GamePriceDeal instance) =>
    <String, dynamic>{
      'store': instance.store,
      'icon': instance.icon,
      'price': instance.price,
      'retail_price': instance.retailPrice,
      'url': instance.url,
    };
