// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_entry_mod_request.g.dart';

@JsonSerializable()
class UpdateEntryModRequest {
  const UpdateEntryModRequest({this.name, this.url});

  factory UpdateEntryModRequest.fromJson(Map<String, Object?> json) =>
      _$UpdateEntryModRequestFromJson(json);

  final String? name;
  final String? url;

  Map<String, Object?> toJson() => _$UpdateEntryModRequestToJson(this);
}
