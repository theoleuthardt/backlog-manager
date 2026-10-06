// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backlog_entry_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BacklogEntryResponse _$BacklogEntryResponseFromJson(
  Map<String, dynamic> json,
) => BacklogEntryResponse(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  genre: (json['genre'] as List<dynamic>).map((e) => e as String).toList(),
  platform: (json['platform'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  status: json['status'] as String,
  owned: json['owned'] as bool,
  interest: (json['interest'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  inSharedSpace: json['in_shared_space'] as bool? ?? false,
  releaseDate: json['release_date'] == null
      ? null
      : DateTime.parse(json['release_date'] as String),
  imageLink: json['image_link'] as String?,
  description: json['description'] as String?,
  trailerLink: json['trailer_link'] as String?,
  mainTime: json['main_time'] as String?,
  mainPlusExtraTime: json['main_plus_extra_time'] as String?,
  completionTime: json['completion_time'] as String?,
  playtime: json['playtime'] as String?,
  partnerPlaytime: json['partner_playtime'] as String?,
  steamAppId: (json['steam_app_id'] as num?)?.toInt(),
  reviewStars: (json['review_stars'] as num?)?.toInt(),
  review: json['review'] as String?,
  note: json['note'] as String?,
  completedAt: json['completed_at'] == null
      ? null
      : DateTime.parse(json['completed_at'] as String),
);

Map<String, dynamic> _$BacklogEntryResponseToJson(
  BacklogEntryResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'genre': instance.genre,
  'platform': instance.platform,
  'status': instance.status,
  'owned': instance.owned,
  'interest': instance.interest,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'release_date': instance.releaseDate?.toIso8601String(),
  'image_link': instance.imageLink,
  'description': instance.description,
  'trailer_link': instance.trailerLink,
  'main_time': instance.mainTime,
  'main_plus_extra_time': instance.mainPlusExtraTime,
  'completion_time': instance.completionTime,
  'playtime': instance.playtime,
  'partner_playtime': instance.partnerPlaytime,
  'in_shared_space': instance.inSharedSpace,
  'steam_app_id': instance.steamAppId,
  'review_stars': instance.reviewStars,
  'review': instance.review,
  'note': instance.note,
  'completed_at': instance.completedAt?.toIso8601String(),
};
