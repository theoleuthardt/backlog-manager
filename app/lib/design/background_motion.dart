import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _backgroundKey = 'blm-animated-background';
const _glowKey = 'blm-animated-glow';
const _blurKey = 'blm-blur-effects';

/// Keeps on the device whether a motion of the window is on (the sky, the glow
/// of a cover). A store that cannot be read or written is ignored.
abstract interface class BackgroundMotionStore {
  Future<bool?> read();

  Future<void> write({required bool enabled});
}

class PreferencesBackgroundMotionStore implements BackgroundMotionStore {
  const PreferencesBackgroundMotionStore([this.key = _backgroundKey]);

  final String key;

  @override
  Future<bool?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write({required bool enabled}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, enabled);
    } on Object {
      return;
    }
  }
}

final backgroundMotionStoreProvider = Provider<BackgroundMotionStore>(
  (ref) => const PreferencesBackgroundMotionStore(),
);

/// Whether a motion is on: the background of the window (twinkling and
/// drifting stars, shooting stars, breathing nebulae) or the glow behind a
/// cover. On by default; a setting of the device, not of the account.
class BackgroundMotionNotifier extends Notifier<bool> {
  BackgroundMotionNotifier(this._store);

  final Provider<BackgroundMotionStore> _store;
  var _chosen = false;

  @override
  bool build() {
    unawaited(_load(ref.read(_store)));
    return true;
  }

  Future<void> _load(BackgroundMotionStore store) async {
    final stored = await store.read();
    if (ref.mounted && !_chosen && stored != null) state = stored;
  }

  void setEnabled({required bool enabled}) {
    _chosen = true;
    state = enabled;
    unawaited(ref.read(_store).write(enabled: enabled));
  }
}

final backgroundMotionProvider =
    NotifierProvider<BackgroundMotionNotifier, bool>(
      () => BackgroundMotionNotifier(backgroundMotionStoreProvider),
    );

final glowMotionStoreProvider = Provider<BackgroundMotionStore>(
  (ref) => const PreferencesBackgroundMotionStore(_glowKey),
);

/// Whether the glow behind the cover in the details drifts and breathes.
final glowMotionProvider = NotifierProvider<BackgroundMotionNotifier, bool>(
  () => BackgroundMotionNotifier(glowMotionStoreProvider),
);

final blurEffectsStoreProvider = Provider<BackgroundMotionStore>(
  (ref) => const PreferencesBackgroundMotionStore(_blurKey),
);

/// Whether the glass of the window blurs what is behind it. On by default;
/// turning it off is the first thing for a slow graphics card, since the blur
/// behind a moving sky is the costliest part of the window.
final blurEffectsProvider = NotifierProvider<BackgroundMotionNotifier, bool>(
  () => BackgroundMotionNotifier(blurEffectsStoreProvider),
);
