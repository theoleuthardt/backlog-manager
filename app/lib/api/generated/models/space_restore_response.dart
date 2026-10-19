// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'restore_request_response.dart';
import 'restore_result.dart';

part 'space_restore_response.g.dart';

@JsonSerializable()
class SpaceRestoreResponse {
  const SpaceRestoreResponse({
    required this.restored,
    this.request,
    this.result,
  });

  factory SpaceRestoreResponse.fromJson(Map<String, Object?> json) =>
      _$SpaceRestoreResponseFromJson(json);

  final bool restored;
  final RestoreRequestResponse? request;
  final RestoreResult? result;

  Map<String, Object?> toJson() => _$SpaceRestoreResponseToJson(this);
}
