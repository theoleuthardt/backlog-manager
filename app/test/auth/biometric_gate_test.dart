import 'package:backlog_manager/auth/biometric_lock.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/settings/settings_page_test.dart' show openSettings;
import '../shell/shell_harness.dart';
import 'biometric_fakes.dart';

const phone = Size(402, 874);

Future<Harness> pumpLocked(
  WidgetTester tester, {
  required FakeBiometricAuth auth,
  bool enabled = true,
}) async {
  final app = await pumpApp(
    tester,
    size: phone,
    desktop: false,
    settle: false,
    extraOverrides: [
      biometricAuthProvider.overrideWithValue(auth),
      biometricUnlockStoreProvider.overrideWithValue(
        MemoryBiometricUnlockStore(enabled),
      ),
      biometricUnlockAtStartProvider.overrideWithValue(enabled),
    ],
  );
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('with the lock on the app opens on the lock screen', (
    tester,
  ) async {
    final auth = FakeBiometricAuth()..passes = false;
    await pumpLocked(tester, auth: auth);

    expect(find.byKey(const Key('biometric-lock')), findsOneWidget);
    expect(auth.asked, 1);
  });

  testWidgets('a passed check opens the app', (tester) async {
    final auth = FakeBiometricAuth()..passes = false;
    await pumpLocked(tester, auth: auth);

    auth.passes = true;
    await tester.tap(find.byKey(const Key('biometric-unlock')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('biometric-lock')), findsNothing);
    expect(find.byKey(const Key('page-home')), findsOneWidget);
  });

  testWidgets('signing out from the lock lets the next sign-in in', (
    tester,
  ) async {
    final auth = FakeBiometricAuth()..passes = false;
    final app = await pumpLocked(tester, auth: auth);

    await tester.tap(find.byKey(const Key('biometric-sign-out')));
    await tester.pumpAndSettle();

    expect(app.container.read(appLockedProvider), isFalse);
  });

  testWidgets('without the lock the app opens directly', (tester) async {
    final auth = FakeBiometricAuth();
    await pumpLocked(tester, auth: auth, enabled: false);

    expect(find.byKey(const Key('biometric-lock')), findsNothing);
    expect(auth.asked, 0);
  });

  testWidgets('the security tab turns the lock on', (tester) async {
    final auth = FakeBiometricAuth();
    final store = MemoryBiometricUnlockStore();
    await openSettings(
      tester,
      size: const Size(732, 412),
      location: '/settings?tab=security',
      overrides: [
        isDesktopProvider.overrideWithValue(false),
        biometricAuthProvider.overrideWithValue(auth),
        biometricUnlockStoreProvider.overrideWithValue(store),
      ],
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings-biometric')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-biometric')));
    await tester.pumpAndSettle();

    expect(store.enabled, isTrue);
    expect(find.byKey(const Key('biometric-lock')), findsNothing);
  });

  testWidgets('the desktop has no lock', (tester) async {
    await openSettings(tester, location: '/settings?tab=security');

    expect(find.byKey(const Key('settings-biometric')), findsNothing);
  });
}
