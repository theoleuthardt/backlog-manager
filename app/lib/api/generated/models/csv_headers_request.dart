// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'csv_headers_request.g.dart';

@JsonSerializable()
class CsvHeadersRequest {
  const CsvHeadersRequest({required this.content});

  factory CsvHeadersRequest.fromJson(Map<String, Object?> json) =>
      _$CsvHeadersRequestFromJson(json);

  final String content;

  Map<String, Object?> toJson() => _$CsvHeadersRequestToJson(this);
}
