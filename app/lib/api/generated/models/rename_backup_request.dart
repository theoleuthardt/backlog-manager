// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'rename_backup_request.g.dart';

@JsonSerializable()
class RenameBackupRequest {
  const RenameBackupRequest({this.name});

  factory RenameBackupRequest.fromJson(Map<String, Object?> json) =>
      _$RenameBackupRequestFromJson(json);

  final String? name;

  Map<String, Object?> toJson() => _$RenameBackupRequestToJson(this);
}
