// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicUser _$PublicUserFromJson(Map<String, dynamic> json) => PublicUser(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  email: json['email'] as String,
  isAdmin: json['is_admin'] as bool,
  isTwoFactorEnabled: json['is_two_factor_enabled'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  hasSteamApiKey: json['has_steam_api_key'] as bool? ?? false,
  hasIgdbCredentials: json['has_igdb_credentials'] as bool? ?? false,
  hasSteamgriddbApiKey: json['has_steamgriddb_api_key'] as bool? ?? false,
  hasDiscordWebhookUrl: json['has_discord_webhook_url'] as bool? ?? false,
  steamAutoImportEnabled: json['steam_auto_import_enabled'] as bool? ?? false,
  steamWishlistAutoSync: json['steam_wishlist_auto_sync'] as bool? ?? false,
  setupCompleted: json['setup_completed'] as bool? ?? false,
  defaultSort: json['default_sort'] as String? ?? 'status',
  theme: json['theme'] as String? ?? 'dark',
  steamId: json['steam_id'] as String?,
  steamWishlistImportedAt: json['steam_wishlist_imported_at'] == null
      ? null
      : DateTime.parse(json['steam_wishlist_imported_at'] as String),
  steamFamilyIds: json['steam_family_ids'] as String?,
  customThemes: (json['custom_themes'] as List<dynamic>?)
      ?.map((e) => CustomTheme.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PublicUserToJson(PublicUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'is_admin': instance.isAdmin,
      'is_two_factor_enabled': instance.isTwoFactorEnabled,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'steam_id': instance.steamId,
      'has_steam_api_key': instance.hasSteamApiKey,
      'has_igdb_credentials': instance.hasIgdbCredentials,
      'has_steamgriddb_api_key': instance.hasSteamgriddbApiKey,
      'has_discord_webhook_url': instance.hasDiscordWebhookUrl,
      'steam_auto_import_enabled': instance.steamAutoImportEnabled,
      'steam_wishlist_imported_at': instance.steamWishlistImportedAt
          ?.toIso8601String(),
      'steam_wishlist_auto_sync': instance.steamWishlistAutoSync,
      'steam_family_ids': instance.steamFamilyIds,
      'setup_completed': instance.setupCompleted,
      'default_sort': instance.defaultSort,
      'theme': instance.theme,
      'custom_themes': instance.customThemes,
    };
