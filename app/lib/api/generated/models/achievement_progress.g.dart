// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AchievementProgress _$AchievementProgressFromJson(Map<String, dynamic> json) =>
    AchievementProgress(
      unlocked: (json['unlocked'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      achievements: (json['achievements'] as List<dynamic>)
          .map((e) => AchievementInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AchievementProgressToJson(
  AchievementProgress instance,
) => <String, dynamic>{
  'unlocked': instance.unlocked,
  'total': instance.total,
  'achievements': instance.achievements,
};
