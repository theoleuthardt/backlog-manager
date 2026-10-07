import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart';
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
    this.defaultSort,
    this.steamId,
    this.steamApiKey,
    this.igdbClientId,
    this.igdbClientSecret,
    this.setupCompleted,
  });

  final String? theme;
  final String? defaultSort;
  final String? steamId;
  final String? steamApiKey;
  final String? igdbClientId;
  final String? igdbClientSecret;
  final bool? setupCompleted;

  Map<String, Object?> toJson() => {
    'theme': ?theme,
    'default_sort': ?defaultSort,
    'steam_id': ?steamId,
    'steam_api_key': ?steamApiKey,
    'igdb_client_id': ?igdbClientId,
    'igdb_client_secret': ?igdbClientSecret,
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
    final user = PublicUser.fromJson(response.data!);
    return SessionUser(
      name: user.name,
      email: user.email,
      setupCompleted: user.setupCompleted,
    );
  }
}

final userApiProvider = Provider<UserApi>(
  (ref) => ApiUserApi(() => ref.read(apiDioProvider.future)),
);
