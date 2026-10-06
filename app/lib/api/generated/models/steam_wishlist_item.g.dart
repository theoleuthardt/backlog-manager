// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'steam_wishlist_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SteamWishlistItem _$SteamWishlistItemFromJson(Map<String, dynamic> json) =>
    SteamWishlistItem(
      appid: (json['appid'] as num).toInt(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      dateAdded: (json['date_added'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SteamWishlistItemToJson(SteamWishlistItem instance) =>
    <String, dynamic>{
      'appid': instance.appid,
      'priority': instance.priority,
      'date_added': instance.dateAdded,
    };
