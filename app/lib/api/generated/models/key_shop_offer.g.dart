// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'key_shop_offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KeyShopOffer _$KeyShopOfferFromJson(Map<String, dynamic> json) => KeyShopOffer(
  shop: json['shop'] as String,
  title: json['title'] as String,
  price: json['price'] as num,
  currency: json['currency'] as String,
  url: json['url'] as String,
  fetchedAt: DateTime.parse(json['fetched_at'] as String),
  discountPct: (json['discount_pct'] as num?)?.toInt(),
);

Map<String, dynamic> _$KeyShopOfferToJson(KeyShopOffer instance) =>
    <String, dynamic>{
      'shop': instance.shop,
      'title': instance.title,
      'price': instance.price,
      'currency': instance.currency,
      'url': instance.url,
      'fetched_at': instance.fetchedAt.toIso8601String(),
      'discount_pct': instance.discountPct,
    };
