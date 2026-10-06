// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BackupSummary _$BackupSummaryFromJson(Map<String, dynamic> json) =>
    BackupSummary(
      id: (json['id'] as num).toInt(),
      kind: json['kind'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      entryCount: (json['entry_count'] as num).toInt(),
      categoryCount: (json['category_count'] as num).toInt(),
      name: json['name'] as String?,
    );

Map<String, dynamic> _$BackupSummaryToJson(BackupSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'created_at': instance.createdAt.toIso8601String(),
      'entry_count': instance.entryCount,
      'category_count': instance.categoryCount,
      'name': instance.name,
    };
