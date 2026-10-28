import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Face ID, Touch ID or a fingerprint (or the device code where the system
/// falls back to it). Tests replace it.
abstract interface class BiometricAuth {
  /// Whether the device can check the user at all.
  Future<bool> isAvailable();

  /// Asks the user; true once they passed.
  Future<bool> authenticate();
}

class DeviceBiometricAuth implements BiometricAuth {
  DeviceBiometricAuth();

  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Backlog Manager',
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}

final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => DeviceBiometricAuth(),
);

/// Whether the settings offer the lock: only where the device can check its
/// user.
final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricAuthProvider).isAvailable(),
);

const _unlockKey = 'blm-biometric-unlock';

/// Keeps on the device whether the app asks for Face ID or a fingerprint.
abstract interface class BiometricUnlockStore {
  /// The stored choice, false when none is stored, null when the device
  /// could not be read.
  Future<bool?> read();

  /// Stores [enabled]; false when the device did not take it.
  Future<bool> write({required bool enabled});
}

class PreferencesBiometricUnlockStore implements BiometricUnlockStore {
  const PreferencesBiometricUnlockStore();

  @override
  Future<bool?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_unlockKey) ?? false;
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> write({required bool enabled}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_unlockKey, enabled);
    } on Object {
      return false;
    }
  }
}

final biometricUnlockStoreProvider = Provider<BiometricUnlockStore>(
  (ref) => const PreferencesBiometricUnlockStore(),
);

/// Whether the lock is on when the app starts; `main` reads it from the
/// device before the first frame (so nothing of the backlog shows before the
/// lock), and a setting the device cannot read counts as on, so a failure
/// never opens the app (Sign out stays the way out); everything else starts
/// with it off.
final biometricUnlockAtStartProvider = Provider<bool>((ref) => false);

/// Whether the app asks for Face ID or a fingerprint when it starts and when
/// it comes back after a while; a setting of the device, off by default.
class BiometricUnlockNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(biometricUnlockAtStartProvider);

  /// Turns the lock on once the user passed the check, so a device whose
  /// biometrics do not work cannot lock its owner out; off needs no check.
  /// The switch only moves once the device stored the choice.
  Future<bool> setEnabled({required bool enabled}) async {
    if (enabled && !await ref.read(biometricAuthProvider).authenticate()) {
      return false;
    }
    if (!ref.mounted) return false;
    final stored = await ref
        .read(biometricUnlockStoreProvider)
        .write(enabled: enabled);
    if (!stored || !ref.mounted) return false;
    state = enabled;
    ref.read(appLockedProvider.notifier).unlock();
    return true;
  }
}

final biometricUnlockProvider = NotifierProvider<BiometricUnlockNotifier, bool>(
  BiometricUnlockNotifier.new,
);

/// How long the app may stay in the background before it locks again.
const relockAfter = Duration(minutes: 5);

/// Whether the lock is closed: at the start, and again after the app was in
/// the background for [relockAfter]; it only matters while
/// [biometricUnlockProvider] is on. A sign-in with the password (which proves
/// the account, see `AuthController`) and signing out (the way out when the
/// check fails) open it; only the session that `main` restores at the start
/// stays locked.
class AppLockedNotifier extends Notifier<bool> {
  DateTime? _hiddenAt;

  @override
  bool build() {
    ref.listen(sessionProvider, (previous, next) {
      if (previous is SessionSignedIn && next is! SessionSignedIn) {
        state = false;
      }
    });
    return true;
  }

  void unlock() => state = false;

  void hidden(DateTime now) => _hiddenAt = now;

  void shown(DateTime now) {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt != null && now.difference(hiddenAt) >= relockAfter) {
      state = true;
    }
  }

  /// Asks the user and opens the lock when they pass.
  Future<void> tryUnlock() async {
    if (await ref.read(biometricAuthProvider).authenticate() && ref.mounted) {
      unlock();
    }
  }
}

final appLockedProvider = NotifierProvider<AppLockedNotifier, bool>(
  AppLockedNotifier.new,
);
