// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_category_request.g.dart';

@JsonSerializable()
class CreateCategoryRequest {
  const CreateCategoryRequest({
    required this.categoryName,
    this.color = '#000000',
    this.description = 'No description',
  });

  factory CreateCategoryRequest.fromJson(Map<String, Object?> json) =>
      _$CreateCategoryRequestFromJson(json);

  @JsonKey(name: 'category_name')
  final String categoryName;
  final String color;
  final String description;

  Map<String, Object?> toJson() => _$CreateCategoryRequestToJson(this);
}
