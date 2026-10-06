// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'steam_preview_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SteamPreviewItem _$SteamPreviewItemFromJson(Map<String, dynamic> json) =>
    SteamPreviewItem(
      steamAppId: (json['steam_app_id'] as num).toInt(),
      title: json['title'] as String,
      imageLink: json['image_link'] as String?,
      playtime: json['playtime'] as String?,
    );

Map<String, dynamic> _$SteamPreviewItemToJson(SteamPreviewItem instance) =>
    <String, dynamic>{
      'steam_app_id': instance.steamAppId,
      'title': instance.title,
      'image_link': instance.imageLink,
      'playtime': instance.playtime,
    };
