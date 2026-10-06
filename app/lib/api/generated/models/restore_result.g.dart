// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restore_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RestoreResult _$RestoreResultFromJson(Map<String, dynamic> json) =>
    RestoreResult(
      entryCount: (json['entry_count'] as num).toInt(),
      categoryCount: (json['category_count'] as num).toInt(),
      safetyBackupId: (json['safety_backup_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RestoreResultToJson(RestoreResult instance) =>
    <String, dynamic>{
      'entry_count': instance.entryCount,
      'category_count': instance.categoryCount,
      'safety_backup_id': instance.safetyBackupId,
    };
