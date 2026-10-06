// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_backlog_entry_request.g.dart';

@JsonSerializable()
class UpdateBacklogEntryRequest {
  const UpdateBacklogEntryRequest({
    this.title,
    this.genre,
    this.platform,
    this.status,
    this.owned,
    this.interest,
    this.releaseDate,
    this.imageLink,
    this.description,
    this.trailerLink,
    this.mainTime,
    this.mainPlusExtraTime,
    this.completionTime,
    this.playtime,
    this.steamAppId,
    this.reviewStars,
    this.review,
    this.note,
  });

  factory UpdateBacklogEntryRequest.fromJson(Map<String, Object?> json) =>
      _$UpdateBacklogEntryRequestFromJson(json);

  final String? title;
  final List<String>? genre;
  final List<String>? platform;
  final String? status;
  final bool? owned;
  final int? interest;
  @JsonKey(name: 'release_date')
  final DateTime? releaseDate;
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
  final String? playtime;
  @JsonKey(name: 'steam_app_id')
  final int? steamAppId;
  @JsonKey(name: 'review_stars')
  final num? reviewStars;
  final String? review;
  final String? note;

  Map<String, Object?> toJson() => _$UpdateBacklogEntryRequestToJson(this);
}
