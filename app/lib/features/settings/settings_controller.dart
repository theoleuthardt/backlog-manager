import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/user_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the line at the bottom of the settings says.
enum SettingsSave { idle, saving, saved, failed }

/// Saves settings of the account: sends the changed fields and reads the
/// account again, so the window shows what the server holds.
class SettingsController extends Notifier<SettingsSave> {
  int _latest = 0;

  @override
  SettingsSave build() {
    ref.watch(sessionGenerationProvider);
    return SettingsSave.idle;
  }

  /// Saves [update]; the result is the message of the error, or null when it
  /// worked. The messages of the backend are kept, for example the one for a
  /// Discord address that is not a webhook.
  ///
  /// Saves can overlap; only the latest one sets the status, so an old one that
  /// ends late cannot turn "Saved" into "Not saved" or the other way round.
  Future<String?> save(UserUpdate update) async {
    final mine = ++_latest;
    state = SettingsSave.saving;
    try {
      await ref.read(userApiProvider).update(update);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mine == _latest) state = SettingsSave.saved;
      return null;
    } on Object catch (error) {
      if (mine == _latest) state = SettingsSave.failed;
      return ApiException.from(error, 'Failed to save settings').message;
    }
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsSave>(SettingsController.new);
