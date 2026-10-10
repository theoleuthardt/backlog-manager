import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/data/theme_store.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Changes the theme of the app and keeps it: in the app at once, on the
/// device and, when a user is signed in, on the account. A failed save puts
/// the previous theme back. Every call returns an error message or null.
class ThemeActions {
  ThemeActions(this._ref);

  final Ref _ref;

  String get _id => _ref.read(themeIdProvider);
  List<CustomTheme> get _custom => _ref.read(customThemesProvider);

  void _apply(String id, List<CustomTheme> custom) {
    _ref.read(themeIdProvider.notifier).select(id);
    _ref.read(customThemesProvider.notifier).set(custom);
    unawaited(_ref.read(themeStoreProvider).write(id, custom));
  }

  /// Applies the theme stored with the account or on the device, without
  /// saving it again.
  void restore(String id, List<CustomTheme> custom) {
    _ref.read(themeIdProvider.notifier).select(id);
    _ref.read(customThemesProvider.notifier).set(custom);
  }

  Future<String?> _persist(
    String id,
    List<CustomTheme> custom, {
    required bool includeCustom,
  }) async {
    final previousId = _id;
    final previousCustom = _custom;
    _apply(id, custom);
    final signedIn = _ref.read(sessionUserProvider) != null;
    if (!signedIn) return null;
    try {
      final user = await _ref
          .read(userApiProvider)
          .update(
            UserUpdate(theme: id, customThemes: includeCustom ? custom : null),
          );
      if (_ref.mounted) _ref.read(sessionProvider.notifier).signIn(user);
      return null;
    } on Object catch (error) {
      if (_ref.mounted) _apply(previousId, previousCustom);
      return ApiException.from(error, 'Failed to save theme').message;
    }
  }

  Future<String?> setTheme(String id) =>
      _persist(id, _custom, includeCustom: false);

  /// Saves a new or edited custom theme and switches to it.
  Future<String?> saveCustom(CustomTheme theme) {
    final exists = _custom.any((existing) => existing.id == theme.id);
    return _persist(
      theme.id,
      exists
          ? [
              for (final existing in _custom)
                existing.id == theme.id ? theme : existing,
            ]
          : [..._custom, theme],
      includeCustom: true,
    );
  }

  /// Deletes a custom theme; deleting the active one falls back to the
  /// default theme.
  Future<String?> deleteCustom(String id) {
    return _persist(_id == id ? defaultThemeId : _id, [
      for (final existing in _custom)
        if (existing.id != id) existing,
    ], includeCustom: true);
  }
}

final themeActionsProvider = Provider<ThemeActions>(ThemeActions.new);

/// Keeps the theme of the app in step with the account and the device: the
/// theme stored on the device applies at start, and the theme of the account
/// applies whenever the signed-in user changes. Watched by the app.
final themeSyncProvider = Provider<void>((ref) {
  final actions = ref.read(themeActionsProvider);

  void applyAccount(SessionUser? user) {
    final theme = user?.theme;
    if (user == null || theme == null) return;
    actions.restore(theme, user.customThemes);
    unawaited(ref.read(themeStoreProvider).write(theme, user.customThemes));
  }

  unawaited(() async {
    final cached = await ref.read(themeStoreProvider).read();
    if (cached == null || !ref.mounted) return;
    if (ref.read(sessionUserProvider) == null) {
      actions.restore(cached.id, cached.customThemes);
    }
  }());
  scheduleMicrotask(() {
    if (ref.mounted) applyAccount(ref.read(sessionUserProvider));
  });
  ref.listen(sessionUserProvider, (_, user) => applyAccount(user));
});
