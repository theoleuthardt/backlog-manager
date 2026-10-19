// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'restore_request_response.dart';
import 'space_backup_summary.dart';

part 'space_backup_list.g.dart';

@JsonSerializable()
class SpaceBackupList {
  const SpaceBackupList({required this.backups, this.restoreRequest});

  factory SpaceBackupList.fromJson(Map<String, Object?> json) =>
      _$SpaceBackupListFromJson(json);

  final List<SpaceBackupSummary> backups;
  @JsonKey(name: 'restore_request')
  final RestoreRequestResponse? restoreRequest;

  Map<String, Object?> toJson() => _$SpaceBackupListToJson(this);
}
