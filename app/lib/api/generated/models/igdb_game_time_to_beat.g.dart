// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'igdb_game_time_to_beat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IgdbGameTimeToBeat _$IgdbGameTimeToBeatFromJson(Map<String, dynamic> json) =>
    IgdbGameTimeToBeat(
      id: (json['id'] as num).toInt(),
      checksum: json['checksum'] as String?,
      completely: (json['completely'] as num?)?.toInt(),
      count: (json['count'] as num?)?.toInt(),
      createdAt: (json['created_at'] as num?)?.toInt(),
      gameId: (json['game_id'] as num?)?.toInt(),
      hastily: (json['hastily'] as num?)?.toInt(),
      normally: (json['normally'] as num?)?.toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$IgdbGameTimeToBeatToJson(IgdbGameTimeToBeat instance) =>
    <String, dynamic>{
      'id': instance.id,
      'checksum': instance.checksum,
      'completely': instance.completely,
      'count': instance.count,
      'created_at': instance.createdAt,
      'game_id': instance.gameId,
      'hastily': instance.hastily,
      'normally': instance.normally,
      'updated_at': instance.updatedAt,
    };
