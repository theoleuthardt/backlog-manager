// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'submit_csv_entry.g.dart';

@JsonSerializable()
class SubmitCsvEntry {
  const SubmitCsvEntry({
    required this.title,
    required this.genre,
    required this.platform,
    required this.status,
    required this.owned,
    this.playtime,
    this.reviewStars,
    this.note,
    this.review,
    this.completedAt,
    this.imageLink,
    this.description,
    this.trailerLink,
    this.mainTime,
    this.mainPlusExtraTime,
    this.completionTime,
  });

  factory SubmitCsvEntry.fromJson(Map<String, Object?> json) =>
      _$SubmitCsvEntryFromJson(json);

  final String title;
  final String genre;
  final List<String> platform;
  final String status;
  final bool owned;
  final String? playtime;
  @JsonKey(name: 'review_stars')
  final num? reviewStars;
  final String? note;
  final String? review;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'image_link')
  final String? imageLink;
  final String? description;
  @JsonKey(name: 'trailer_link')
  final String? trailerLink;
  @JsonKey(name: 'main_time')
  final String? mainTime;
  @JsonKey(name: 'main_plus_extra_time')
  final String? mainPlusExtraTime;
  @JsonKey(name: 'completion_time')
  final String? completionTime;

  Map<String, Object?> toJson() => _$SubmitCsvEntryToJson(this);
}
