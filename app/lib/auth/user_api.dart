import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' hide CustomTheme;
import 'package:backlog_manager/auth/session_user_mapper.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A partial update of the signed-in user (`PUT /api/user/me`). Only the
/// fields that are set are sent. The generated `UpdateOwnUserRequest` is not
/// used for this, because it sends every field and the backend reads an
/// explicit `null` as "clear this field", so one changed setting would erase
/// the others.
class UserUpdate {
  const UserUpdate({
    this.theme,
    this.customThemes,
    this.defaultSort,
    this.steamId,
    this.steamApiKey,
    this.igdbClientId,
    this.igdbClientSecret,
    this.steamFamilyIds,
    this.steamgriddbApiKey,
    this.discordWebhookUrl,
    this.steamWishlistAutoSync,
    this.setupCompleted,
  });

  final String? theme;
  final List<CustomTheme>? customThemes;
  final String? defaultSort;
  final String? steamId;
  final String? steamApiKey;
  final String? igdbClientId;
  final String? igdbClientSecret;
  final String? steamFamilyIds;
  final String? steamgriddbApiKey;
  final String? discordWebhookUrl;
  final bool? steamWishlistAutoSync;
  final bool? setupCompleted;

  Map<String, Object?> toJson() => {
    'theme': ?theme,
    'custom_themes': ?customThemes?.map((theme) => theme.toJson()).toList(),
    'default_sort': ?defaultSort,
    'steam_id': ?steamId,
    'steam_api_key': ?steamApiKey,
    'igdb_client_id': ?igdbClientId,
    'igdb_client_secret': ?igdbClientSecret,
    'steam_family_ids': ?steamFamilyIds,
    'steamgriddb_api_key': ?steamgriddbApiKey,
    'discord_webhook_url': ?discordWebhookUrl,
    'steam_wishlist_auto_sync': ?steamWishlistAutoSync,
    'setup_completed': ?setupCompleted,
  };

  bool get isEmpty => toJson().isEmpty;
}

abstract interface class UserApi {
  /// Saves [update] and returns the user as it is now.
  Future<SessionUser> update(UserUpdate update);
}

class ApiUserApi implements UserApi {
  const ApiUserApi(this._dio);

  final Future<Dio> Function() _dio;

  @override
  Future<SessionUser> update(UserUpdate update) async {
    final response = await (await _dio()).put<Map<String, dynamic>>(
      '/api/user/me',
      data: update.toJson(),
    );
    return sessionUserFrom(PublicUser.fromJson(response.data!));
  }
}

final userApiProvider = Provider<UserApi>(
  (ref) => ApiUserApi(() => ref.read(apiDioProvider.future)),
);
