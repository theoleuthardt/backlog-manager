// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncSummary _$SyncSummaryFromJson(Map<String, dynamic> json) => SyncSummary(
  users: (json['users'] as num?)?.toInt() ?? 0,
  added: (json['added'] as num?)?.toInt() ?? 0,
  removed: (json['removed'] as num?)?.toInt() ?? 0,
  failed: (json['failed'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SyncSummaryToJson(SyncSummary instance) =>
    <String, dynamic>{
      'users': instance.users,
      'added': instance.added,
      'removed': instance.removed,
      'failed': instance.failed,
    };
