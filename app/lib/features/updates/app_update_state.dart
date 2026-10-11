import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UpdateCheck { idle, checking, available, upToDate, failed }

class AppUpdateState {
  const AppUpdateState({
    this.check = UpdateCheck.idle,
    this.release,
    this.announced = false,
  });

  final UpdateCheck check;

  /// The newer release while [check] is [UpdateCheck.available].
  final AppRelease? release;

  /// Whether the notification of this session was shown already.
  final bool announced;

  AppUpdateState copyWith({
    UpdateCheck? check,
    AppRelease? release,
    bool? announced,
    bool clearRelease = false,
  }) {
    return AppUpdateState(
      check: check ?? this.check,
      release: clearRelease ? null : release ?? this.release,
      announced: announced ?? this.announced,
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
      if (release != null && isNewerVersion(release.version, than: installed)) {
        state = state.copyWith(check: UpdateCheck.available, release: release);
      } else {
        state = state.copyWith(check: UpdateCheck.upToDate, clearRelease: true);
      }
    } on Object {
      if (!ref.mounted) return;
      state = quiet ? before : state.copyWith(check: UpdateCheck.failed);
    }
  }

  void markAnnounced() => state = state.copyWith(announced: true);
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);
