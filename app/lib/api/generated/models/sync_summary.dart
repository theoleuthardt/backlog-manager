// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'sync_summary.g.dart';

@JsonSerializable()
class SyncSummary {
  const SyncSummary({
    this.users = 0,
    this.added = 0,
    this.removed = 0,
    this.failed = 0,
  });

  factory SyncSummary.fromJson(Map<String, Object?> json) =>
      _$SyncSummaryFromJson(json);

  final int users;
  final int added;
  final int removed;
  final int failed;

  Map<String, Object?> toJson() => _$SyncSummaryToJson(this);
}
