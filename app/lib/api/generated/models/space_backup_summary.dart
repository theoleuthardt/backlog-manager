// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'space_backup_summary.g.dart';

@JsonSerializable()
class SpaceBackupSummary {
  const SpaceBackupSummary({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.entryCount,
    required this.categoryCount,
    this.name,
    this.createdBy,
  });

  factory SpaceBackupSummary.fromJson(Map<String, Object?> json) =>
      _$SpaceBackupSummaryFromJson(json);

  final int id;
  final String kind;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'entry_count')
  final int entryCount;
  @JsonKey(name: 'category_count')
  final int categoryCount;
  final String? name;
  @JsonKey(name: 'created_by')
  final String? createdBy;

  Map<String, Object?> toJson() => _$SpaceBackupSummaryToJson(this);
}
