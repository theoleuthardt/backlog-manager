// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum UpdateOwnUserRequestDefaultSort {
  @JsonValue('status')
  status('status'),
  @JsonValue('category')
  category('category'),
  @JsonValue('genre')
  genre('genre'),
  @JsonValue('playtime')
  playtime('playtime'),
  @JsonValue('platform')
  platform('platform'),
  @JsonValue('interest')
  interest('interest'),
  @JsonValue('review_stars')
  reviewStars('review_stars'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const UpdateOwnUserRequestDefaultSort(this.json);

  factory UpdateOwnUserRequestDefaultSort.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<UpdateOwnUserRequestDefaultSort> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
