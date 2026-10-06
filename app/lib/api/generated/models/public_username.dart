// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'public_username.g.dart';

@JsonSerializable()
class PublicUsername {
  const PublicUsername({required this.id, required this.name});

  factory PublicUsername.fromJson(Map<String, Object?> json) =>
      _$PublicUsernameFromJson(json);

  final int id;
  final String name;

  Map<String, Object?> toJson() => _$PublicUsernameToJson(this);
}
