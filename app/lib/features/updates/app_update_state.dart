import 'dart:convert';
import 'dart:io';

import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/data/update_download.dart';
import 'package:backlog_manager/data/update_public_key.dart';
import 'package:backlog_manager/data/update_verifier.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:backlog_manager/platform/update_installer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [older] is the answer when the newest release of the channel is older than
/// the installed version, as on Stable while a pre-release is installed.
enum UpdateCheck { idle, checking, available, older, upToDate, failed }

/// Where an in-place update is: nothing started, the installer is loading,
/// it is being checked, it is ready to be applied by a restart, or it failed
/// (the installed version keeps working).
enum UpdateInstall { none, downloading, verifying, ready, installing, failed }

class AppUpdateState {
  const AppUpdateState({
    this.check = UpdateCheck.idle,
    this.release,
    this.announced = false,
    this.install = UpdateInstall.none,
    this.progress,
    this.installError,
    this.staged,
  });

  final UpdateCheck check;

  /// The in-place update of [release].
  final UpdateInstall install;

  /// 0 to 1 while the installer loads, when its size is known.
  final double? progress;
  final String? installError;

  /// The verified installer while [install] is [UpdateInstall.ready].
  final File? staged;

  /// The newer release while [check] is [UpdateCheck.available], the older
  /// newest one while it is [UpdateCheck.older].
  final AppRelease? release;

  /// Whether the notification of this session was shown already.
  final bool announced;

  AppUpdateState copyWith({
    UpdateCheck? check,
    AppRelease? release,
    bool? announced,
    bool clearRelease = false,
    UpdateInstall? install,
    double? progress,
    String? installError,
    File? staged,
    bool clearInstall = false,
  }) {
    return AppUpdateState(
      check: check ?? this.check,
      release: clearRelease ? null : release ?? this.release,
      announced: announced ?? this.announced,
      install: clearInstall ? UpdateInstall.none : install ?? this.install,
      progress: clearInstall ? null : progress ?? this.progress,
      installError: clearInstall ? null : installError ?? this.installError,
      staged: clearInstall ? null : staged ?? this.staged,
    );
  }
}

/// Whether the app looks for a new release on its own when it starts: in
/// release builds only, so development and tests make no request.
final automaticUpdateCheckProvider = Provider<bool>((ref) => kReleaseMode);

/// The state of the update check: a quiet check on start (a failure leaves
/// the state as it was) and the manual one of the settings (a failure is
/// reported).
class AppUpdateNotifier extends Notifier<AppUpdateState> {
  @override
  AppUpdateState build() => const AppUpdateState();

  Future<void> check({bool quiet = false}) async {
    if (state.check == UpdateCheck.checking) return;
    final before = state;
    state = state.copyWith(check: UpdateCheck.checking);
    try {
      final installed = await ref.read(installedVersionProvider.future);
      final release = await ref.read(releaseSourceProvider).latest();
      if (!ref.mounted) return;
      _dropStaleInstall(release);
      if (release != null && isNewerVersion(release.version, than: installed)) {
        state = state.copyWith(check: UpdateCheck.available, release: release);
      } else if (release != null &&
          isNewerVersion(installed, than: release.version)) {
        state = state.copyWith(check: UpdateCheck.older, release: release);
      } else {
        state = state.copyWith(check: UpdateCheck.upToDate, clearRelease: true);
      }
    } on Object {
      if (!ref.mounted) return;
      state = quiet ? before : state.copyWith(check: UpdateCheck.failed);
    }
  }

  /// A ready or failed install belongs to the release it was started for: a
  /// check that finds another release (after a change of channel, say) removes
  /// the downloaded file and its state, so the buttons never apply to a
  /// version they do not name.
  void _dropStaleInstall(AppRelease? found) {
    final install = state.install;
    if (install != UpdateInstall.ready && install != UpdateInstall.failed) {
      return;
    }
    if (state.release?.version == found?.version) return;
    final file = state.staged;
    if (file != null && file.existsSync()) file.deleteSync();
    state = state.copyWith(clearInstall: true);
  }

  void markAnnounced() => state = state.copyWith(announced: true);

  /// Whether this install can apply the newer release in place: the release
  /// published a payload for it, the app knows the key to verify it with, and
  /// the install can replace itself.
  bool get canInstallInPlace {
    final release = state.release;
    final key = ref.read(updateInstallerProvider)?.payloadKey;
    return release?.manifest?.payloads[key] != null &&
        ref.read(updateVerifierProvider) != null;
  }

  /// Downloads the installer of [AppUpdateState.release], checks its size,
  /// hash and signature and leaves it ready for [restart]. Any failure keeps
  /// the installed version and removes what was downloaded.
  Future<void> install() async {
    final release = state.release;
    final installer = ref.read(updateInstallerProvider);
    final verifier = ref.read(updateVerifierProvider);
    final key = installer?.payloadKey;
    final payload = release?.manifest?.payloads[key];
    if (release == null ||
        installer == null ||
        verifier == null ||
        key == null ||
        payload == null ||
        state.install == UpdateInstall.downloading ||
        state.install == UpdateInstall.verifying) {
      return;
    }
    state = state.copyWith(
      install: UpdateInstall.downloading,
      progress: 0,
      clearInstall: false,
    );
    final file = File(
      '${installer.stagingDirectory.path}/.blm-update-${release.version}',
    );
    Future<void> fail(String message) async {
      if (file.existsSync()) file.deleteSync();
      if (!ref.mounted) return;
      state = AppUpdateState(
        check: state.check,
        release: state.release,
        announced: state.announced,
        install: UpdateInstall.failed,
        installError: message,
      );
    }

    try {
      await ref
          .read(updateDownloaderProvider)
          .download(
            payload.url,
            file,
            onProgress: (received, total) {
              if (!ref.mounted || total <= 0) return;
              state = state.copyWith(progress: received / total);
            },
          );
    } on Object {
      await fail('The download failed. Check the connection and try again.');
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(install: UpdateInstall.verifying);
    final UpdateVerdict verdict;
    try {
      verdict = await verifier.verify(
        file: file,
        payload: payload,
        version: release.version,
        key: key,
      );
    } on Object {
      await fail(
        'The update could not be verified and was not installed. '
        'Your version keeps working.',
      );
      return;
    }
    if (verdict != UpdateVerdict.ok) {
      await fail(
        'The update could not be verified and was not installed. '
        'Your version keeps working.',
      );
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(install: UpdateInstall.ready, staged: file);
  }

  /// Applies the verified installer and ends the app; the new version starts
  /// by itself. A failure leaves the installed version running.
  Future<void> restart() async {
    final file = state.staged;
    final installer = ref.read(updateInstallerProvider);
    if (state.install != UpdateInstall.ready ||
        file == null ||
        installer == null) {
      return;
    }
    state = state.copyWith(install: UpdateInstall.installing);
    try {
      await installer.apply(file);
    } on Object {
      if (file.existsSync()) file.deleteSync();
      if (!ref.mounted) return;
      state = AppUpdateState(
        check: state.check,
        release: state.release,
        announced: state.announced,
        install: UpdateInstall.failed,
        installError:
            'The update could not be installed. Your version keeps working.',
      );
      return;
    }
    ref.read(appExitProvider)();
  }
}

/// The verifier for the key built into the app, or null while there is none.
final updateVerifierProvider = Provider<UpdateVerifier?>((ref) {
  if (updatePublicKeyBase64.isEmpty) return null;
  return UpdateVerifier(
    Uint8List.fromList(base64Decode(updatePublicKeyBase64)),
  );
});

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);
