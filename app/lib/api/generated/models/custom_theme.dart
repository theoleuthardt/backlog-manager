// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'custom_theme.g.dart';

@JsonSerializable()
class CustomTheme {
  const CustomTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.foreground,
    required this.accent,
    required this.border,
    required this.glow,
  });

  factory CustomTheme.fromJson(Map<String, Object?> json) =>
      _$CustomThemeFromJson(json);

  final String id;
  final String name;
  final String background;
  final String surface;
  final String foreground;
  final String accent;
  final String border;
  final String glow;

  Map<String, Object?> toJson() => _$CustomThemeToJson(this);
}
