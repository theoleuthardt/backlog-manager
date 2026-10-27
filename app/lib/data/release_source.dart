import 'dart:convert';

import 'package:backlog_manager/data/update_channel.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:backlog_manager/domain/update_manifest.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Where the app learns about its newest release of the chosen channel.
abstract interface class ReleaseSource {
  /// The newest published release, or null when there is none (or it is not
  /// a plain version). Throws when the answer could not be fetched.
  Future<AppRelease?> latest();
}

const _repositoryUrl =
    'https://api.github.com/repos/theoleuthardt/backlog-manager/releases';
const _manifestAsset = 'app-update.json';

/// Finds the newest release that published an `app-update.json` and reads it,
/// so the app can update itself in place. The Preview channel also takes
/// pre-releases and `releases/latest` does not return those, so the list is
/// read first; without a manifest anywhere the answer is
/// `releases/latest`, which GitHub already answers without drafts and
/// pre-releases, and the app only points at the release page. On the stable
/// channel the pre-releases of the list are skipped, on the preview channel
/// they count.
class GithubReleaseSource implements ReleaseSource {
  GithubReleaseSource([Dio? dio, this.channel = UpdateChannel.stable])
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
  final UpdateChannel channel;

  @override
  Future<AppRelease?> latest() async {
    final withManifest = await _newestWithManifest();
    if (withManifest != null) return withManifest;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_repositoryUrl/latest',
      );
      final data = response.data;
      return data == null ? null : appReleaseFromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<AppRelease?> _newestWithManifest() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        _repositoryUrl,
        queryParameters: {'per_page': 20},
      );
      for (final item in response.data ?? const <dynamic>[]) {
        if (item is! Map || item['draft'] == true) continue;
        if (channel == UpdateChannel.stable && item['prerelease'] == true) {
          continue;
        }
        final assets = item['assets'];
        if (assets is! List) continue;
        for (final asset in assets) {
          if (asset is! Map || asset['name'] != _manifestAsset) continue;
          final url = asset['browser_download_url'];
          final uri = url is String ? Uri.tryParse(url) : null;
          if (uri == null ||
              uri.scheme != 'https' ||
              uri.host != 'github.com') {
            continue;
          }
          final manifest = await _readManifest(uri);
          if (manifest == null) continue;
          return AppRelease(
            version: manifest.version,
            pageUrl: manifest.pageUrl,
            notes: manifest.notes,
            manifest: manifest,
          );
        }
      }
    } on DioException {
      return null;
    }
    return null;
  }

  /// Reads the manifest as text and decodes it here: GitHub serves a release
  /// asset as `application/octet-stream`, which a JSON response type would
  /// hand over undecoded. Text that is not JSON is no manifest.
  Future<UpdateManifest?> _readManifest(Uri url) async {
    final response = await _dio.getUri<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    try {
      return parseUpdateManifest(jsonDecode(response.data ?? ''));
    } on FormatException {
      return null;
    }
  }
}

final releaseSourceProvider = Provider<ReleaseSource>(
  (ref) => GithubReleaseSource(null, ref.watch(updateChannelProvider)),
);

/// The installed version as `1.2.3`, from the build.
final installedVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
