// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'key_shop_offer.g.dart';

@JsonSerializable()
class KeyShopOffer {
  const KeyShopOffer({
    required this.shop,
    required this.title,
    required this.price,
    required this.currency,
    required this.url,
    required this.fetchedAt,
    this.discountPct,
  });

  factory KeyShopOffer.fromJson(Map<String, Object?> json) =>
      _$KeyShopOfferFromJson(json);

  final String shop;
  final String title;
  final num price;
  final String currency;
  final String url;
  @JsonKey(name: 'fetched_at')
  final DateTime fetchedAt;
  @JsonKey(name: 'discount_pct')
  final int? discountPct;

  Map<String, Object?> toJson() => _$KeyShopOfferToJson(this);
}
