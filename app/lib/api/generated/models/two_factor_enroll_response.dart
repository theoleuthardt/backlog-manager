// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'two_factor_enroll_response.g.dart';

@JsonSerializable()
class TwoFactorEnrollResponse {
  const TwoFactorEnrollResponse({
    required this.secret,
    required this.otpauthUrl,
  });

  factory TwoFactorEnrollResponse.fromJson(Map<String, Object?> json) =>
      _$TwoFactorEnrollResponseFromJson(json);

  final String secret;
  @JsonKey(name: 'otpauth_url')
  final String otpauthUrl;

  Map<String, Object?> toJson() => _$TwoFactorEnrollResponseToJson(this);
}
