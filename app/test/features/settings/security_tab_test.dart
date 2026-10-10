import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/two_factor_api.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'settings_page_test.dart' show Settings, openSettings, theo;

class FakeTwoFactorApi implements TwoFactorApi {
  FakeTwoFactorApi({this.onVerified});

  final calls = <String>[];
  Future<TwoFactorEnrollment> Function()? onEnroll;
  Future<List<String>> Function(String code)? onVerify;
  Future<void> Function(String password)? onDisable;
  void Function()? onVerified;

  @override
  Future<TwoFactorEnrollment> enroll() {
    calls.add('enroll');
    return onEnroll?.call() ??
        Future.value(
          const TwoFactorEnrollment(
            secret: 'JBSWY3DPEHPK3PXP',
            otpauthUrl: 'otpauth://totp/Backlog:theo?secret=JBSWY3DPEHPK3PXP',
          ),
        );
  }

  @override
  Future<List<String>> verify(String code) async {
    calls.add('verify $code');
    final custom = onVerify;
    final codes = custom == null
        ? const ['aaaa-1111', 'bbbb-2222', 'cccc-3333', 'dddd-4444']
        : await custom(code);
    onVerified?.call();
    return codes;
  }

  @override
  Future<void> disable(String password) async {
    calls.add('disable $password');
    await onDisable?.call(password);
  }
}

const security = '/settings?tab=security';

Future<(Settings, FakeTwoFactorApi)> open(
  WidgetTester tester, {
  bool enabled = false,
  void Function(FakeTwoFactorApi api)? setUp,
}) async {
  final api = FakeTwoFactorApi();
  setUp?.call(api);
  final settings = await openSettings(
    tester,
    location: security,
    user: SessionUser(
      name: theo.name,
      email: theo.email,
      setupCompleted: true,
      isTwoFactorEnabled: enabled,
    ),
    overrides: [twoFactorApiProvider.overrideWithValue(api)],
  );
  api.onVerified = () => settings.mutateAccount(
    (account) => SessionUser(
      name: account.name,
      email: account.email,
      setupCompleted: true,
      isTwoFactorEnabled: true,
    ),
  );
  return (settings, api);
}

Future<void> startEnrol(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('two-factor-enable')));
  await tester.pumpAndSettle();
}

Future<void> typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField).last, code);
  await tester.pump();
}

void main() {
  group('the status', () {
    testWidgets('offers to enable it', (tester) async {
      await open(tester);

      expect(find.text('Not enabled'), findsOneWidget);
      expect(
        find.text('Add an extra layer of security using an authenticator app.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('two-factor-enable')), findsOneWidget);
      expect(find.byKey(const Key('two-factor-disable')), findsNothing);
    });

    testWidgets('offers to disable it when it is on', (tester) async {
      await open(tester, enabled: true);

      expect(find.text('Enabled'), findsOneWidget);
      expect(
        find.text('Two-factor authentication is enabled on your account.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('two-factor-disable')), findsOneWidget);
    });
  });

  group('enabling', () {
    testWidgets('shows the QR code and the key to type in', (tester) async {
      final (_, api) = await open(tester);

      await startEnrol(tester);

      expect(api.calls, ['enroll']);
      expect(find.text('Set up two-factor authentication'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        find.text("Can't scan it? Enter this code manually"),
        findsOneWidget,
      );
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
    });

    testWidgets('says that it generates the secret while it waits', (
      tester,
    ) async {
      final pending = Completer<TwoFactorEnrollment>();
      await open(tester, setUp: (api) => api.onEnroll = () => pending.future);

      await tester.tap(find.byKey(const Key('two-factor-enable')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('two-factor-generating')), findsOneWidget);
      pending.complete(
        const TwoFactorEnrollment(secret: 'S', otpauthUrl: 'otpauth://x'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('two-factor-generating')), findsNothing);
    });

    testWidgets('closes with a message when the setup cannot start', (
      tester,
    ) async {
      await open(
        tester,
        setUp: (api) =>
            api.onEnroll = () async =>
                throw const ApiException('Two-factor is not configured'),
      );

      await startEnrol(tester);

      expect(find.text('Two-factor is not configured'), findsOneWidget);
      expect(find.text('Set up two-factor authentication'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('needs a code before it verifies', (tester) async {
      final (_, api) = await open(tester);
      await startEnrol(tester);

      await tester.tap(find.byKey(const Key('two-factor-verify')));
      await tester.pump();
      expect(api.calls, ['enroll']);

      await typeCode(tester, '123 456');
      await tester.tap(find.byKey(const Key('two-factor-verify')));
      await tester.pumpAndSettle();

      expect(api.calls, ['enroll', 'verify 123 456']);
    });

    testWidgets('shows the backup codes and then the enabled state', (
      tester,
    ) async {
      await open(tester);
      await startEnrol(tester);
      await typeCode(tester, '123456');

      await tester.tap(find.byKey(const Key('two-factor-verify')));
      await tester.pumpAndSettle();

      expect(find.text('Save your backup codes'), findsOneWidget);
      for (final code in ['aaaa-1111', 'bbbb-2222', 'cccc-3333', 'dddd-4444']) {
        expect(find.text(code), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('two-factor-done')));
      await tester.pumpAndSettle();
      expect(find.text('Save your backup codes'), findsNothing);
      expect(find.text('Enabled'), findsOneWidget);
      expect(find.byKey(const Key('two-factor-disable')), findsOneWidget);
    });

    testWidgets('keeps the backup codes when the account cannot be read', (
      tester,
    ) async {
      final (settings, _) = await open(tester);
      await startEnrol(tester);
      await typeCode(tester, '123456');
      settings.failRefreshes(true);

      await tester.tap(find.byKey(const Key('two-factor-verify')));
      await tester.pumpAndSettle();

      expect(find.text('Save your backup codes'), findsOneWidget);
      expect(find.text('aaaa-1111'), findsOneWidget);
      expect(find.text('Invalid two-factor code'), findsNothing);
      expect(find.textContaining('offline'), findsNothing);
    });

    testWidgets('stays on the code step for a wrong code', (tester) async {
      await open(
        tester,
        setUp: (api) =>
            api.onVerify = (code) async =>
                throw const ApiException('Invalid two-factor code'),
      );
      await startEnrol(tester);
      await typeCode(tester, '000000');

      await tester.tap(find.byKey(const Key('two-factor-verify')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid two-factor code'), findsOneWidget);
      expect(find.text('Set up two-factor authentication'), findsOneWidget);
      expect(find.text('Not enabled'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('the backup codes', () {
    Future<void> toCodes(WidgetTester tester) async {
      await open(tester);
      await startEnrol(tester);
      await typeCode(tester, '123456');
      await tester.tap(find.byKey(const Key('two-factor-verify')));
      await tester.pumpAndSettle();
    }

    testWidgets('can be copied', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await toCodes(tester);

      await tester.tap(find.byKey(const Key('two-factor-copy')));
      await tester.pumpAndSettle();

      expect(copied, 'aaaa-1111\nbbbb-2222\ncccc-3333\ndddd-4444');
      expect(find.text('Backup codes copied to clipboard'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('tell the user to copy them by hand when copying fails', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await toCodes(tester);

      await tester.tap(find.byKey(const Key('two-factor-copy')));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not copy the backup codes. Copy them manually.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('disabling', () {
    testWidgets('asks for the password and warns about the backup codes', (
      tester,
    ) async {
      final (_, api) = await open(tester, enabled: true);

      await tester.tap(find.byKey(const Key('two-factor-disable')));
      await tester.pumpAndSettle();

      expect(find.text('Disable two-factor authentication?'), findsOneWidget);
      expect(
        find.text(
          'Enter your password to confirm. Your backup codes will stop working.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('two-factor-disable-confirm')));
      await tester.pump();
      expect(api.calls, isEmpty);
    });

    testWidgets('turns it off with the password', (tester) async {
      final (settings, api) = await open(tester, enabled: true);
      settings.mutateAccount(
        (account) => SessionUser(
          name: account.name,
          email: account.email,
          setupCompleted: true,
        ),
      );
      await tester.tap(find.byKey(const Key('two-factor-disable')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'hunter2hunter2');
      await tester.pump();

      await tester.tap(find.byKey(const Key('two-factor-disable-confirm')));
      await tester.pumpAndSettle();

      expect(api.calls, ['disable hunter2hunter2']);
      expect(find.text('Two-factor authentication disabled'), findsOneWidget);
      expect(find.text('Not enabled'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('reports success when the account cannot be read after', (
      tester,
    ) async {
      final (settings, api) = await open(tester, enabled: true);
      await tester.tap(find.byKey(const Key('two-factor-disable')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'hunter2hunter2');
      await tester.pump();
      settings.failRefreshes(true);

      await tester.tap(find.byKey(const Key('two-factor-disable-confirm')));
      await tester.pumpAndSettle();

      expect(api.calls, ['disable hunter2hunter2']);
      expect(find.text('Two-factor authentication disabled'), findsOneWidget);
      expect(
        find.text('Failed to disable two-factor authentication'),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('stays open with the message for a wrong password', (
      tester,
    ) async {
      await open(
        tester,
        enabled: true,
        setUp: (api) =>
            api.onDisable = (password) async =>
                throw const ApiException('Invalid password'),
      );
      await tester.tap(find.byKey(const Key('two-factor-disable')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'wrong');
      await tester.pump();

      await tester.tap(find.byKey(const Key('two-factor-disable-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid password'), findsOneWidget);
      expect(find.text('Disable two-factor authentication?'), findsOneWidget);
      expect(find.text('Enabled'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Cancel leaves it on', (tester) async {
      final (_, api) = await open(tester, enabled: true);
      await tester.tap(find.byKey(const Key('two-factor-disable')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Disable two-factor authentication?'), findsNothing);
      expect(api.calls, isEmpty);
    });
  });

  testWidgets('golden: the setup sheet', tags: 'golden', (tester) async {
    await open(tester);
    await startEnrol(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/two_factor_setup.png'),
    );
  });

  testWidgets('golden: the backup codes', tags: 'golden', (tester) async {
    await open(tester);
    await startEnrol(tester);
    await typeCode(tester, '123456');
    await tester.tap(find.byKey(const Key('two-factor-verify')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/two_factor_backup_codes.png'),
    );
  });
}
