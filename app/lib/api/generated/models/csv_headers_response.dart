// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'csv_headers_response.g.dart';

@JsonSerializable()
class CsvHeadersResponse {
  const CsvHeadersResponse({required this.headers});

  factory CsvHeadersResponse.fromJson(Map<String, Object?> json) =>
      _$CsvHeadersResponseFromJson(json);

  final Map<String, String> headers;

  Map<String, Object?> toJson() => _$CsvHeadersResponseToJson(this);
}
