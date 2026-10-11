import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'blm-animated-background';

/// Keeps on the device whether the sky of the window moves. A store that
/// cannot be read or written is ignored.
abstract interface class BackgroundMotionStore {
  Future<bool?> read();

  Future<void> write({required bool enabled});
}

class PreferencesBackgroundMotionStore implements BackgroundMotionStore {
  const PreferencesBackgroundMotionStore();

  @override
  Future<bool?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_storageKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write({required bool enabled}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, enabled);
    } on Object {
      return;
    }
  }
}

final backgroundMotionStoreProvider = Provider<BackgroundMotionStore>(
  (ref) => const PreferencesBackgroundMotionStore(),
);

/// Whether the background of the window is animated (twinkling and drifting
/// stars, shooting stars, breathing nebulae). On by default; a setting of the
/// device, not of the account.
class BackgroundMotionNotifier extends Notifier<bool> {
  var _chosen = false;

  @override
  bool build() {
    unawaited(_load(ref.read(backgroundMotionStoreProvider)));
    return true;
  }

  Future<void> _load(BackgroundMotionStore store) async {
    final stored = await store.read();
    if (ref.mounted && !_chosen && stored != null) state = stored;
  }

  void setEnabled({required bool enabled}) {
    _chosen = true;
    state = enabled;
    unawaited(ref.read(backgroundMotionStoreProvider).write(enabled: enabled));
  }
}

final backgroundMotionProvider =
    NotifierProvider<BackgroundMotionNotifier, bool>(
      BackgroundMotionNotifier.new,
    );
