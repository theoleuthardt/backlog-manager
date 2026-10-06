// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_csv_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchCsvRequest _$MatchCsvRequestFromJson(Map<String, dynamic> json) =>
    MatchCsvRequest(
      content: json['content'] as String,
      titleColumn: json['title_column'] as String,
      genreColumn: json['genre_column'] as String,
      platformColumn: json['platform_column'] as String,
      statusColumn: json['status_column'] as String,
      playtimeColumn: json['playtime_column'] as String?,
      ratingColumn: json['rating_column'] as String?,
      completedAtColumn: json['completed_at_column'] as String?,
      noteColumns: (json['note_columns'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      reviewColumns: (json['review_columns'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$MatchCsvRequestToJson(MatchCsvRequest instance) =>
    <String, dynamic>{
      'content': instance.content,
      'title_column': instance.titleColumn,
      'genre_column': instance.genreColumn,
      'platform_column': instance.platformColumn,
      'status_column': instance.statusColumn,
      'playtime_column': instance.playtimeColumn,
      'rating_column': instance.ratingColumn,
      'completed_at_column': instance.completedAtColumn,
      'note_columns': instance.noteColumns,
      'review_columns': instance.reviewColumns,
    };
