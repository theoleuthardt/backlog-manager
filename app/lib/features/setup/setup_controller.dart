import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const setupSteps = ['Theme', 'Sorting', 'Steam', 'IGDB', 'Done'];

const igdbBothOrNeitherMessage =
    'Enter both the IGDB Client ID and Client Secret, or neither';

/// What the setup wizard holds: the current step, the values of the steps and
/// the state of the last save.
class SetupState {
  const SetupState({
    this.step = 0,
    this.saving = false,
    this.error,
    this.defaultSort = 'status',
    this.steamId = '',
    this.steamApiKey = '',
    this.igdbClientId = '',
    this.igdbClientSecret = '',
  });

  final int step;
  final bool saving;
  final String? error;
  final String defaultSort;
  final String steamId;
  final String steamApiKey;
  final String igdbClientId;
  final String igdbClientSecret;

  bool get isLastStep => step == setupSteps.length - 1;

  SetupState copyWith({
    int? step,
    bool? saving,
    String? error,
    bool clearError = false,
    String? defaultSort,
    String? steamId,
    String? steamApiKey,
    String? igdbClientId,
    String? igdbClientSecret,
  }) {
    return SetupState(
      step: step ?? this.step,
      saving: saving ?? this.saving,
      error: clearError ? null : error ?? this.error,
      defaultSort: defaultSort ?? this.defaultSort,
      steamId: steamId ?? this.steamId,
      steamApiKey: steamApiKey ?? this.steamApiKey,
      igdbClientId: igdbClientId ?? this.igdbClientId,
      igdbClientSecret: igdbClientSecret ?? this.igdbClientSecret,
    );
  }
}

/// The first-run wizard: each step saves its values when the user goes on, a
/// failed save keeps the user on the step, and finishing or skipping marks the
/// setup as completed.
class SetupController extends Notifier<SetupState> {
  @override
  SetupState build() => const SetupState();

  void setDefaultSort(String value) =>
      state = state.copyWith(defaultSort: value);

  void setSteamId(String value) => state = state.copyWith(steamId: value);

  void setSteamApiKey(String value) =>
      state = state.copyWith(steamApiKey: value);

  void setIgdbClientId(String value) =>
      state = state.copyWith(igdbClientId: value);

  void setIgdbClientSecret(String value) =>
      state = state.copyWith(igdbClientSecret: value);

  void back() {
    if (state.step > 0 && !state.saving) {
      state = state.copyWith(step: state.step - 1, clearError: true);
    }
  }

  Future<void> next() async {
    if (state.saving) return;
    final update = _updateOfStep();
    if (update == null) return;
    if (!update.isEmpty && !await _save(update)) return;
    state = state.copyWith(step: state.step + 1, clearError: true);
  }

  /// Marks the setup as completed; the route guard then leads to Home.
  Future<void> finish() async {
    if (state.saving) return;
    if (!await _save(const UserUpdate(setupCompleted: true))) return;
    await ref.read(authControllerProvider.notifier).refreshUser();
  }

  Future<void> skip() => finish();

  /// What the current step saves, or null when it cannot go on.
  UserUpdate? _updateOfStep() {
    switch (state.step) {
      case 0:
        return UserUpdate(theme: ref.read(themeIdProvider));
      case 1:
        return UserUpdate(defaultSort: state.defaultSort);
      case 2:
        final steamId = state.steamId.trim();
        final apiKey = state.steamApiKey.trim();
        return UserUpdate(
          steamId: steamId.isEmpty ? null : steamId,
          steamApiKey: apiKey.isEmpty ? null : apiKey,
        );
      case 3:
        final id = state.igdbClientId.trim();
        final secret = state.igdbClientSecret.trim();
        if (id.isEmpty != secret.isEmpty) {
          state = state.copyWith(error: igdbBothOrNeitherMessage);
          return null;
        }
        return id.isEmpty
            ? const UserUpdate()
            : UserUpdate(igdbClientId: id, igdbClientSecret: secret);
      default:
        return const UserUpdate();
    }
  }

  Future<bool> _save(UserUpdate update) async {
    state = state.copyWith(saving: true, clearError: true);
    try {
      await ref.read(userApiProvider).update(update);
      state = state.copyWith(saving: false);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        saving: false,
        error: ApiException.from(error, 'Failed to save settings').message,
      );
      return false;
    }
  }
}

final setupControllerProvider = NotifierProvider<SetupController, SetupState>(
  SetupController.new,
);
