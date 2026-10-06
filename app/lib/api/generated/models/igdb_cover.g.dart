// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'igdb_cover.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IgdbCover _$IgdbCoverFromJson(Map<String, dynamic> json) => IgdbCover(
  id: (json['id'] as num).toInt(),
  alphaChannel: json['alpha_channel'] as bool?,
  animated: json['animated'] as bool?,
  checksum: json['checksum'] as String?,
  game: (json['game'] as num?)?.toInt(),
  gameLocalization: (json['game_localization'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  imageId: json['image_id'] as String?,
  url: json['url'] as String?,
  width: (json['width'] as num?)?.toInt(),
);

Map<String, dynamic> _$IgdbCoverToJson(IgdbCover instance) => <String, dynamic>{
  'id': instance.id,
  'alpha_channel': instance.alphaChannel,
  'animated': instance.animated,
  'checksum': instance.checksum,
  'game': instance.game,
  'game_localization': instance.gameLocalization,
  'height': instance.height,
  'image_id': instance.imageId,
  'url': instance.url,
  'width': instance.width,
};
