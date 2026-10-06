// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_theme.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomTheme _$CustomThemeFromJson(Map<String, dynamic> json) => CustomTheme(
  id: json['id'] as String,
  name: json['name'] as String,
  background: json['background'] as String,
  surface: json['surface'] as String,
  foreground: json['foreground'] as String,
  accent: json['accent'] as String,
  border: json['border'] as String,
  glow: json['glow'] as String,
);

Map<String, dynamic> _$CustomThemeToJson(CustomTheme instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'background': instance.background,
      'surface': instance.surface,
      'foreground': instance.foreground,
      'accent': instance.accent,
      'border': instance.border,
      'glow': instance.glow,
    };
