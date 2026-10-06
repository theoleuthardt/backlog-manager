// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'custom_status_response.g.dart';

@JsonSerializable()
class CustomStatusResponse {
  const CustomStatusResponse({required this.id, required this.name});

  factory CustomStatusResponse.fromJson(Map<String, Object?> json) =>
      _$CustomStatusResponseFromJson(json);

  final int id;
  final String name;

  Map<String, Object?> toJson() => _$CustomStatusResponseToJson(this);
}
