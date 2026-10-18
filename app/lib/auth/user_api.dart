import 'dart:typed_data';

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
    'steam_wishlist_auto_sync': ?steamWishlistAutoSync,
    'setup_completed': ?setupCompleted,
  };

  bool get isEmpty => toJson().isEmpty;
}

abstract interface class UserApi {
  /// Saves [update] and returns the user as it is now.
  Future<SessionUser> update(UserUpdate update);

  /// Sets the profile picture (PNG, JPEG or WebP, at most 512 KB) and returns
  /// the user as it is now.
  Future<SessionUser> setAvatar(Uint8List bytes, String contentType);

  /// Removes the profile picture and returns the user as it is now.
  Future<SessionUser> removeAvatar();

  /// The picture of the user [userId] (the caller or the partner of the
  /// Shared Space), or null when there is none or it may not be read.
  Future<Uint8List?> avatar(int userId);
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

  Future<SessionUser> _own() async {
    final response = await (await _dio()).get<Map<String, dynamic>>(
      '/api/user/me',
    );
    return sessionUserFrom(PublicUser.fromJson(response.data!));
  }

  @override
  Future<SessionUser> setAvatar(Uint8List bytes, String contentType) async {
    await (await _dio()).put<void>(
      '/api/user/avatar',
      data: bytes,
      options: Options(contentType: contentType),
    );
    return _own();
  }

  @override
  Future<SessionUser> removeAvatar() async {
    await (await _dio()).delete<void>('/api/user/avatar');
    return _own();
  }

  @override
  Future<Uint8List?> avatar(int userId) async {
    try {
      final response = await (await _dio()).get<List<int>>(
        '/api/user/$userId/avatar',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

final userApiProvider = Provider<UserApi>(
  (ref) => ApiUserApi(() => ref.read(apiDioProvider.future)),
);
