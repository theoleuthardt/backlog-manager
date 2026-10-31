import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:backlog_manager/domain/whats_new.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app reads the notes of the release of one version.
abstract interface class ReleaseNotesSource {
  /// The release of [version] (`1.2.3`), pre-releases included, or null when
  /// the version has none. Throws when the answer could not be fetched.
  Future<AppRelease?> release(String version);
}

class GithubReleaseNotesSource implements ReleaseNotesSource {
  GithubReleaseNotesSource([Dio? dio])
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
  Future<AppRelease?> release(String version) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$releasesApiUrl/tags/v$version',
      );
      final data = response.data;
      return data == null
          ? null
          : appReleaseFromJson(data, allowPrerelease: true);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

final releaseNotesSourceProvider = Provider<ReleaseNotesSource>(
  (ref) => GithubReleaseNotesSource(),
);

const _storageKey = 'blm-whats-new-seen';

/// Keeps the version whose changes were last shown, on the device. A store
/// that cannot be read or written is ignored.
abstract interface class WhatsNewStore {
  Future<String?> read();

  Future<void> write(String version);
}

class PreferencesWhatsNewStore implements WhatsNewStore {
  const PreferencesWhatsNewStore();

  @override
  Future<String?> read() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_storageKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String version) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _storageKey,
        version,
      );
    } on Object {
      return;
    }
  }
}

final whatsNewStoreProvider = Provider<WhatsNewStore>(
  (ref) => const PreferencesWhatsNewStore(),
);

/// The changes of the installed version that are still to be shown.
class WhatsNew {
  const WhatsNew({
    required this.version,
    required this.changes,
    required this.pageUrl,
  });

  final String version;
  final List<String> changes;
  final Uri pageUrl;
}

/// What is new in the installed version, or null when there is nothing to
/// show: on a first install (which only remembers the version), when the
/// version was shown already or is older than the one shown (a newer one is
/// kept), and for a release without changes in its notes. A release that cannot be fetched shows nothing this time and is
/// asked for again at the next start.
class WhatsNewNotifier extends AsyncNotifier<WhatsNew?> {
  @override
  Future<WhatsNew?> build() async {
    final installed = await ref.watch(installedVersionProvider.future);
    final store = ref.read(whatsNewStoreProvider);
    final lastSeen = await store.read();
    if (!shouldShowWhatsNew(
      installed: installed,
      lastSeen: lastSeen,
      inUseBefore: ref.read(sessionRestoredProvider),
    )) {
      if (lastSeen == null) await store.write(installed);
      return null;
    }
    final AppRelease? release;
    try {
      release = await ref.read(releaseNotesSourceProvider).release(installed);
    } on Object {
      return null;
    }
    if (release == null) return null;
    final changes = releaseChanges(release.notes);
    if (changes.isEmpty) {
      await store.write(installed);
      return null;
    }
    return WhatsNew(
      version: installed,
      changes: changes,
      pageUrl: release.pageUrl,
    );
  }

  /// The changes were shown: they do not come again for this version.
  Future<void> seen() async {
    final shown = state.value;
    if (shown == null) return;
    state = const AsyncData(null);
    await ref.read(whatsNewStoreProvider).write(shown.version);
  }
}

final whatsNewProvider = AsyncNotifierProvider<WhatsNewNotifier, WhatsNew?>(
  WhatsNewNotifier.new,
);
