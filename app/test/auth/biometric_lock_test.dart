import 'package:backlog_manager/auth/biometric_lock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'biometric_fakes.dart';

ProviderContainer containerWith(
  FakeBiometricAuth auth,
  MemoryBiometricUnlockStore store,
) {
  final container = ProviderContainer(
    overrides: [
      biometricAuthProvider.overrideWithValue(auth),
      biometricUnlockStoreProvider.overrideWithValue(store),
      biometricUnlockAtStartProvider.overrideWithValue(store.enabled),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts with what main read, off without it', () {
    final off = containerWith(
      FakeBiometricAuth(),
      MemoryBiometricUnlockStore(),
    );
    expect(off.read(biometricUnlockProvider), isFalse);

    final on = ProviderContainer(
      overrides: [biometricUnlockAtStartProvider.overrideWithValue(true)],
    );
    addTearDown(on.dispose);
    expect(on.read(biometricUnlockProvider), isTrue);
  });

  test('turning it on needs a passed check and stores it', () async {
    final auth = FakeBiometricAuth()..passes = false;
    final store = MemoryBiometricUnlockStore();
    final container = containerWith(auth, store);
    final notifier = container.read(biometricUnlockProvider.notifier);

    expect(await notifier.setEnabled(enabled: true), isFalse);
    expect(store.enabled, isFalse);

    auth.passes = true;
    expect(await notifier.setEnabled(enabled: true), isTrue);
    expect(store.enabled, isTrue);
    expect(container.read(appLockedProvider), isFalse);
  });

  test('turning it off needs no check', () async {
    final auth = FakeBiometricAuth();
    final store = MemoryBiometricUnlockStore(true);
    final container = containerWith(auth, store);

    await container
        .read(biometricUnlockProvider.notifier)
        .setEnabled(enabled: false);

    expect(auth.asked, 0);
    expect(store.enabled, isFalse);
  });

  test('locked at the start, open after a passed check', () async {
    final container = containerWith(
      FakeBiometricAuth(),
      MemoryBiometricUnlockStore(true),
    );
    expect(container.read(biometricUnlockProvider), isTrue);
    expect(container.read(appLockedProvider), isTrue);

    await container.read(appLockedProvider.notifier).tryUnlock();

    expect(container.read(appLockedProvider), isFalse);
  });

  test('a failed check keeps it locked', () async {
    final container = containerWith(
      FakeBiometricAuth()..passes = false,
      MemoryBiometricUnlockStore(true),
    );

    await container.read(appLockedProvider.notifier).tryUnlock();

    expect(container.read(appLockedProvider), isTrue);
  });

  test('locks again only after five minutes in the background', () {
    final container = containerWith(
      FakeBiometricAuth(),
      MemoryBiometricUnlockStore(true),
    );
    final lock = container.read(appLockedProvider.notifier)..unlock();
    final start = DateTime(2026, 10, 28, 8);

    lock
      ..hidden(start)
      ..shown(start.add(const Duration(minutes: 4)));
    expect(container.read(appLockedProvider), isFalse);

    lock
      ..hidden(start)
      ..shown(start.add(relockAfter));
    expect(container.read(appLockedProvider), isTrue);
  });
}
