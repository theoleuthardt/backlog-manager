/// Fakes of the biometric check and of the stored setting.
library;

import 'package:backlog_manager/auth/biometric_lock.dart';

class FakeBiometricAuth implements BiometricAuth {
  bool available = true;
  bool passes = true;
  int asked = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate() async {
    asked++;
    return passes;
  }
}

class MemoryBiometricUnlockStore implements BiometricUnlockStore {
  MemoryBiometricUnlockStore([this.enabled = false]);

  bool enabled;
  bool fails = false;

  @override
  Future<bool?> read() async => enabled;

  @override
  Future<bool> write({required bool enabled}) async {
    if (fails) return false;
    this.enabled = enabled;
    return true;
  }
}
