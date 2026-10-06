// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'match_csv_request.g.dart';

@JsonSerializable()
class MatchCsvRequest {
  const MatchCsvRequest({
    required this.content,
    required this.titleColumn,
    required this.genreColumn,
    required this.platformColumn,
    required this.statusColumn,
    this.playtimeColumn,
    this.ratingColumn,
    this.completedAtColumn,
    this.noteColumns,
    this.reviewColumns,
  });

  factory MatchCsvRequest.fromJson(Map<String, Object?> json) =>
      _$MatchCsvRequestFromJson(json);

  final String content;
  @JsonKey(name: 'title_column')
  final String titleColumn;
  @JsonKey(name: 'genre_column')
  final String genreColumn;
  @JsonKey(name: 'platform_column')
  final String platformColumn;
  @JsonKey(name: 'status_column')
  final String statusColumn;
  @JsonKey(name: 'playtime_column')
  final String? playtimeColumn;
  @JsonKey(name: 'rating_column')
  final String? ratingColumn;
  @JsonKey(name: 'completed_at_column')
  final String? completedAtColumn;
  @JsonKey(name: 'note_columns')
  final List<String>? noteColumns;
  @JsonKey(name: 'review_columns')
  final List<String>? reviewColumns;

  Map<String, Object?> toJson() => _$MatchCsvRequestToJson(this);
}
