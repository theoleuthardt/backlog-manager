// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'game_price_deal.g.dart';

@JsonSerializable()
class GamePriceDeal {
  const GamePriceDeal({
    required this.store,
    required this.icon,
    required this.price,
    required this.retailPrice,
    required this.url,
  });

  factory GamePriceDeal.fromJson(Map<String, Object?> json) =>
      _$GamePriceDealFromJson(json);

  final String store;
  final String icon;
  final num price;
  @JsonKey(name: 'retail_price')
  final num retailPrice;
  final String url;

  Map<String, Object?> toJson() => _$GamePriceDealToJson(this);
}
