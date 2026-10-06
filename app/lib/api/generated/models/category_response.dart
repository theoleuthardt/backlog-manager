// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'category_response.g.dart';

@JsonSerializable()
class CategoryResponse {
  const CategoryResponse({
    required this.id,
    required this.name,
    required this.color,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryResponse.fromJson(Map<String, Object?> json) =>
      _$CategoryResponseFromJson(json);

  final int id;
  final String name;
  final String color;
  final String? description;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => _$CategoryResponseToJson(this);
}
