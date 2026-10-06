// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'custom_theme.dart';

part 'public_user.g.dart';

@JsonSerializable()
class PublicUser {
  const PublicUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.isTwoFactorEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.hasSteamApiKey = false,
    this.hasIgdbCredentials = false,
    this.hasSteamgriddbApiKey = false,
    this.hasDiscordWebhookUrl = false,
    this.steamAutoImportEnabled = false,
    this.setupCompleted = false,
    this.defaultSort = 'status',
    this.theme = 'dark',
    this.steamId,
    this.steamFamilyIds,
    this.customThemes,
  });

  factory PublicUser.fromJson(Map<String, Object?> json) =>
      _$PublicUserFromJson(json);

  final int id;
  final String name;
  final String email;
  @JsonKey(name: 'is_admin')
  final bool isAdmin;
  @JsonKey(name: 'is_two_factor_enabled')
  final bool isTwoFactorEnabled;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'steam_id')
  final String? steamId;
  @JsonKey(name: 'has_steam_api_key')
  final bool hasSteamApiKey;
  @JsonKey(name: 'has_igdb_credentials')
  final bool hasIgdbCredentials;
  @JsonKey(name: 'has_steamgriddb_api_key')
  final bool hasSteamgriddbApiKey;
  @JsonKey(name: 'has_discord_webhook_url')
  final bool hasDiscordWebhookUrl;
  @JsonKey(name: 'steam_auto_import_enabled')
  final bool steamAutoImportEnabled;
  @JsonKey(name: 'steam_family_ids')
  final String? steamFamilyIds;
  @JsonKey(name: 'setup_completed')
  final bool setupCompleted;
  @JsonKey(name: 'default_sort')
  final String defaultSort;
  final String theme;
  @JsonKey(name: 'custom_themes')
  final List<CustomTheme>? customThemes;

  Map<String, Object?> toJson() => _$PublicUserToJson(this);
}
