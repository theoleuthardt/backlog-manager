// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'submit_csv_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubmitCsvEntry _$SubmitCsvEntryFromJson(Map<String, dynamic> json) =>
    SubmitCsvEntry(
      title: json['title'] as String,
      genre: json['genre'] as String,
      platform: (json['platform'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      status: json['status'] as String,
      owned: json['owned'] as bool,
      playtime: json['playtime'] as String?,
      reviewStars: json['review_stars'] as num?,
      note: json['note'] as String?,
      review: json['review'] as String?,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      imageLink: json['image_link'] as String?,
      description: json['description'] as String?,
      trailerLink: json['trailer_link'] as String?,
      mainTime: json['main_time'] as String?,
      mainPlusExtraTime: json['main_plus_extra_time'] as String?,
      completionTime: json['completion_time'] as String?,
    );

Map<String, dynamic> _$SubmitCsvEntryToJson(SubmitCsvEntry instance) =>
    <String, dynamic>{
      'title': instance.title,
      'genre': instance.genre,
      'platform': instance.platform,
      'status': instance.status,
      'owned': instance.owned,
      'playtime': instance.playtime,
      'review_stars': instance.reviewStars,
      'note': instance.note,
      'review': instance.review,
      'completed_at': instance.completedAt?.toIso8601String(),
      'image_link': instance.imageLink,
      'description': instance.description,
      'trailer_link': instance.trailerLink,
      'main_time': instance.mainTime,
      'main_plus_extra_time': instance.mainPlusExtraTime,
      'completion_time': instance.completionTime,
    };
