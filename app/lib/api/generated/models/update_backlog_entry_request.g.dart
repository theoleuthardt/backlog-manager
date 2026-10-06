// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_backlog_entry_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateBacklogEntryRequest _$UpdateBacklogEntryRequestFromJson(
  Map<String, dynamic> json,
) => UpdateBacklogEntryRequest(
  title: json['title'] as String?,
  genre: (json['genre'] as List<dynamic>?)?.map((e) => e as String).toList(),
  platform: (json['platform'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  status: json['status'] as String?,
  owned: json['owned'] as bool?,
  interest: (json['interest'] as num?)?.toInt(),
  releaseDate: json['release_date'] == null
      ? null
      : DateTime.parse(json['release_date'] as String),
  imageLink: json['image_link'] as String?,
  description: json['description'] as String?,
  trailerLink: json['trailer_link'] as String?,
  publisher: json['publisher'] as String?,
  mainTime: json['main_time'] as String?,
  mainPlusExtraTime: json['main_plus_extra_time'] as String?,
  completionTime: json['completion_time'] as String?,
  playtime: json['playtime'] as String?,
  steamAppId: (json['steam_app_id'] as num?)?.toInt(),
  reviewStars: json['review_stars'] as num?,
  review: json['review'] as String?,
  note: json['note'] as String?,
);

Map<String, dynamic> _$UpdateBacklogEntryRequestToJson(
  UpdateBacklogEntryRequest instance,
) => <String, dynamic>{
  'title': instance.title,
  'genre': instance.genre,
  'platform': instance.platform,
  'status': instance.status,
  'owned': instance.owned,
  'interest': instance.interest,
  'release_date': instance.releaseDate?.toIso8601String(),
  'image_link': instance.imageLink,
  'description': instance.description,
  'trailer_link': instance.trailerLink,
  'publisher': instance.publisher,
  'main_time': instance.mainTime,
  'main_plus_extra_time': instance.mainPlusExtraTime,
  'completion_time': instance.completionTime,
  'playtime': instance.playtime,
  'steam_app_id': instance.steamAppId,
  'review_stars': instance.reviewStars,
  'review': instance.review,
  'note': instance.note,
};
