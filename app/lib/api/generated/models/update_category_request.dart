// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_category_request.g.dart';

@JsonSerializable()
class UpdateCategoryRequest {
  const UpdateCategoryRequest({
    this.categoryName,
    this.color,
    this.description,
  });

  factory UpdateCategoryRequest.fromJson(Map<String, Object?> json) =>
      _$UpdateCategoryRequestFromJson(json);

  @JsonKey(name: 'category_name')
  final String? categoryName;
  final String? color;
  final String? description;

  Map<String, Object?> toJson() => _$UpdateCategoryRequestToJson(this);
}
