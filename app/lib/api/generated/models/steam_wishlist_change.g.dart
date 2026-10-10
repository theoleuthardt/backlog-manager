// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'steam_wishlist_change.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SteamWishlistChange _$SteamWishlistChangeFromJson(Map<String, dynamic> json) =>
    SteamWishlistChange(
      steamAppId: (json['steam_app_id'] as num).toInt(),
      title: json['title'] as String,
      imageLink: json['image_link'] as String?,
    );

Map<String, dynamic> _$SteamWishlistChangeToJson(
  SteamWishlistChange instance,
) => <String, dynamic>{
  'steam_app_id': instance.steamAppId,
  'title': instance.title,
  'image_link': instance.imageLink,
};
