// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_own_user_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateOwnUserRequest _$UpdateOwnUserRequestFromJson(
  Map<String, dynamic> json,
) => UpdateOwnUserRequest(
  username: json['username'] as String?,
  email: json['email'] as String?,
  password: json['password'] as String?,
  steamId: json['steam_id'] as String?,
  steamApiKey: json['steam_api_key'] as String?,
  igdbClientId: json['igdb_client_id'] as String?,
  igdbClientSecret: json['igdb_client_secret'] as String?,
  steamgriddbApiKey: json['steamgriddb_api_key'] as String?,
  discordWebhookUrl: json['discord_webhook_url'] as String?,
  steamAutoImportEnabled: json['steam_auto_import_enabled'] as bool?,
  steamFamilyIds: json['steam_family_ids'] as String?,
  setupCompleted: json['setup_completed'] as bool?,
  defaultSort: json['default_sort'] == null
      ? null
      : UpdateOwnUserRequestDefaultSort.fromJson(
          json['default_sort'] as String,
        ),
  theme: json['theme'] as String?,
  customThemes: (json['custom_themes'] as List<dynamic>?)
      ?.map((e) => CustomTheme.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$UpdateOwnUserRequestToJson(
  UpdateOwnUserRequest instance,
) => <String, dynamic>{
  'username': instance.username,
  'email': instance.email,
  'password': instance.password,
  'steam_id': instance.steamId,
  'steam_api_key': instance.steamApiKey,
  'igdb_client_id': instance.igdbClientId,
  'igdb_client_secret': instance.igdbClientSecret,
  'steamgriddb_api_key': instance.steamgriddbApiKey,
  'discord_webhook_url': instance.discordWebhookUrl,
  'steam_auto_import_enabled': instance.steamAutoImportEnabled,
  'steam_family_ids': instance.steamFamilyIds,
  'setup_completed': instance.setupCompleted,
  'default_sort':
      _$UpdateOwnUserRequestDefaultSortEnumMap[instance.defaultSort],
  'theme': instance.theme,
  'custom_themes': instance.customThemes,
};

const _$UpdateOwnUserRequestDefaultSortEnumMap = {
  UpdateOwnUserRequestDefaultSort.status: 'status',
  UpdateOwnUserRequestDefaultSort.category: 'category',
  UpdateOwnUserRequestDefaultSort.genre: 'genre',
  UpdateOwnUserRequestDefaultSort.playtime: 'playtime',
  UpdateOwnUserRequestDefaultSort.platform: 'platform',
  UpdateOwnUserRequestDefaultSort.interest: 'interest',
  UpdateOwnUserRequestDefaultSort.reviewStars: 'review_stars',
  UpdateOwnUserRequestDefaultSort.$unknown: r'$unknown',
};
