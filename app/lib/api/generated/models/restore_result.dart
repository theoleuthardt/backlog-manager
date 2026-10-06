// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'restore_result.g.dart';

@JsonSerializable()
class RestoreResult {
  const RestoreResult({
    required this.entryCount,
    required this.categoryCount,
    this.safetyBackupId,
  });

  factory RestoreResult.fromJson(Map<String, Object?> json) =>
      _$RestoreResultFromJson(json);

  @JsonKey(name: 'entry_count')
  final int entryCount;
  @JsonKey(name: 'category_count')
  final int categoryCount;
  @JsonKey(name: 'safety_backup_id')
  final int? safetyBackupId;

  Map<String, Object?> toJson() => _$RestoreResultToJson(this);
}
