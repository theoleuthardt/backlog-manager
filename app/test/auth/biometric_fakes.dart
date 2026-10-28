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

  @override
  Future<bool?> read() async => enabled;

  @override
  Future<void> write({required bool enabled}) async => this.enabled = enabled;
}
