// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_custom_status_request.g.dart';

@JsonSerializable()
class CreateCustomStatusRequest {
  const CreateCustomStatusRequest({required this.name});

  factory CreateCustomStatusRequest.fromJson(Map<String, Object?> json) =>
      _$CreateCustomStatusRequestFromJson(json);

  final String name;

  Map<String, Object?> toJson() => _$CreateCustomStatusRequestToJson(this);
}
