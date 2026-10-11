import 'package:backlog_manager/domain/app_update.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Where the app learns about its newest stable release.
abstract interface class ReleaseSource {
  /// The newest published release, or null when there is none (or it is not
  /// a plain version). Throws when the answer could not be fetched.
  Future<AppRelease?> latest();
}

const _latestReleaseUrl =
    'https://api.github.com/repos/theoleuthardt/backlog-manager/releases/latest';

/// Reads `releases/latest` of the repository, which GitHub already answers
/// without drafts and pre-releases.
class GithubReleaseSource implements ReleaseSource {
  GithubReleaseSource([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/vnd.github+json'},
            ),
          );

  final Dio _dio;

  @override
  Future<AppRelease?> latest() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_latestReleaseUrl);
      final data = response.data;
      return data == null ? null : appReleaseFromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

final releaseSourceProvider = Provider<ReleaseSource>(
  (ref) => GithubReleaseSource(),
);

/// The installed version as `1.2.3`, from the build.
final installedVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
