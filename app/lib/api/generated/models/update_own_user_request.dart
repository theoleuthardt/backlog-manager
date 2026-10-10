// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'custom_theme.dart';
import 'update_own_user_request_default_sort.dart';

part 'update_own_user_request.g.dart';

@JsonSerializable()
class UpdateOwnUserRequest {
  const UpdateOwnUserRequest({
    this.username,
    this.email,
    this.password,
    this.steamId,
    this.steamApiKey,
    this.igdbClientId,
    this.igdbClientSecret,
    this.steamgriddbApiKey,
    this.discordWebhookUrl,
    this.steamAutoImportEnabled,
    this.steamWishlistAutoSync,
    this.steamFamilyIds,
    this.setupCompleted,
    this.defaultSort,
    this.theme,
    this.customThemes,
  });

  factory UpdateOwnUserRequest.fromJson(Map<String, Object?> json) =>
      _$UpdateOwnUserRequestFromJson(json);

  final String? username;
  final String? email;
  final String? password;
  @JsonKey(name: 'steam_id')
  final String? steamId;
  @JsonKey(name: 'steam_api_key')
  final String? steamApiKey;
  @JsonKey(name: 'igdb_client_id')
  final String? igdbClientId;
  @JsonKey(name: 'igdb_client_secret')
  final String? igdbClientSecret;
  @JsonKey(name: 'steamgriddb_api_key')
  final String? steamgriddbApiKey;
  @JsonKey(name: 'discord_webhook_url')
  final String? discordWebhookUrl;
  @JsonKey(name: 'steam_auto_import_enabled')
  final bool? steamAutoImportEnabled;
  @JsonKey(name: 'steam_wishlist_auto_sync')
  final bool? steamWishlistAutoSync;
  @JsonKey(name: 'steam_family_ids')
  final String? steamFamilyIds;
  @JsonKey(name: 'setup_completed')
  final bool? setupCompleted;
  @JsonKey(name: 'default_sort')
  final UpdateOwnUserRequestDefaultSort? defaultSort;
  final String? theme;
  @JsonKey(name: 'custom_themes')
  final List<CustomTheme>? customThemes;

  Map<String, Object?> toJson() => _$UpdateOwnUserRequestToJson(this);
}
