// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_category_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCategoryRequest _$CreateCategoryRequestFromJson(
  Map<String, dynamic> json,
) => CreateCategoryRequest(
  categoryName: json['category_name'] as String,
  color: json['color'] as String? ?? '#000000',
  description: json['description'] as String? ?? 'No description',
);

Map<String, dynamic> _$CreateCategoryRequestToJson(
  CreateCategoryRequest instance,
) => <String, dynamic>{
  'category_name': instance.categoryName,
  'color': instance.color,
  'description': instance.description,
};
