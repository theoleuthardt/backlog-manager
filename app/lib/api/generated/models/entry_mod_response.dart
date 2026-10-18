// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'entry_mod_response.g.dart';

@JsonSerializable()
class EntryModResponse {
  const EntryModResponse({required this.id, required this.name, this.url});

  factory EntryModResponse.fromJson(Map<String, Object?> json) =>
      _$EntryModResponseFromJson(json);

  final int id;
  final String name;
  final String? url;

  Map<String, Object?> toJson() => _$EntryModResponseToJson(this);
}
