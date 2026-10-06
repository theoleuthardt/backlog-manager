// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_custom_status_request.g.dart';

@JsonSerializable()
class UpdateCustomStatusRequest {
  const UpdateCustomStatusRequest({required this.name});

  factory UpdateCustomStatusRequest.fromJson(Map<String, Object?> json) =>
      _$UpdateCustomStatusRequestFromJson(json);

  final String name;

  Map<String, Object?> toJson() => _$UpdateCustomStatusRequestToJson(this);
}
