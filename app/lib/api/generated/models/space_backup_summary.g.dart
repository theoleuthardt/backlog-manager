// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_backup_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpaceBackupSummary _$SpaceBackupSummaryFromJson(Map<String, dynamic> json) =>
    SpaceBackupSummary(
      id: (json['id'] as num).toInt(),
      kind: json['kind'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      entryCount: (json['entry_count'] as num).toInt(),
      categoryCount: (json['category_count'] as num).toInt(),
      name: json['name'] as String?,
      createdBy: json['created_by'] as String?,
    );

Map<String, dynamic> _$SpaceBackupSummaryToJson(SpaceBackupSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'created_at': instance.createdAt.toIso8601String(),
      'entry_count': instance.entryCount,
      'category_count': instance.categoryCount,
      'name': instance.name,
      'created_by': instance.createdBy,
    };
