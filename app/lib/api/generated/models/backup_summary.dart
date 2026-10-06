// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'backup_summary.g.dart';

@JsonSerializable()
class BackupSummary {
  const BackupSummary({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.entryCount,
    required this.categoryCount,
    this.name,
  });

  factory BackupSummary.fromJson(Map<String, Object?> json) =>
      _$BackupSummaryFromJson(json);

  final int id;
  final String kind;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'entry_count')
  final int entryCount;
  @JsonKey(name: 'category_count')
  final int categoryCount;
  final String? name;

  Map<String, Object?> toJson() => _$BackupSummaryToJson(this);
}
