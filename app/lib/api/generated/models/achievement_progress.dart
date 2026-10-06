// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'achievement_info.dart';

part 'achievement_progress.g.dart';

@JsonSerializable()
class AchievementProgress {
  const AchievementProgress({
    required this.unlocked,
    required this.total,
    required this.achievements,
  });

  factory AchievementProgress.fromJson(Map<String, Object?> json) =>
      _$AchievementProgressFromJson(json);

  final int unlocked;
  final int total;
  final List<AchievementInfo> achievements;

  Map<String, Object?> toJson() => _$AchievementProgressToJson(this);
}
