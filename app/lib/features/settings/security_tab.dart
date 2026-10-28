import 'dart:async';

import 'package:backlog_manager/auth/biometric_lock.dart';
import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/features/settings/settings_widgets.dart';
import 'package:backlog_manager/features/settings/two_factor_sheets.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The security settings: two-factor authentication with an authenticator
/// app, which is set up with a QR code and turned off with the password; on a
/// phone or tablet that can check its user, unlocking the app with Face ID or
/// a fingerprint.
class SecurityTab extends ConsumerWidget {
  const SecurityTab({required this.user, super.key});

  final SessionUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = user.isTwoFactorEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsTabTitle(
          title: 'Security',
          subtitle: 'Protect your account.',
        ),
        ShelfFormGroup(
          title: 'Two-factor authentication',
          rows: [
            ShelfFormRow(
              label: enabled ? 'Enabled' : 'Not enabled',
              description: enabled
                  ? 'Two-factor authentication is enabled on your account.'
                  : 'Add an extra layer of security using an authenticator '
                        'app.',
              control: enabled
                  ? ShelfButton(
                      key: const Key('two-factor-disable'),
                      label: 'Disable Two-Factor Authentication',
                      onPressed: () => showDisableTwoFactorSheet(context),
                    )
                  : ShelfButton(
                      key: const Key('two-factor-enable'),
                      label: 'Enable Two-Factor Authentication',
                      kind: ShelfButtonKind.primary,
                      onPressed: () => showEnrollTwoFactorSheet(context),
                    ),
            ),
          ],
        ),
        if (ShelfFormFactor.isTouch(context) &&
            ref.watch(biometricAvailableProvider).value == true)
          ShelfFormGroup(
            title: 'Unlock',
            rows: [
              ShelfFormRow(
                label: 'Face ID or fingerprint',
                description:
                    'Ask for it when the app starts and after five minutes '
                    'in the background.',
                control: ShelfSwitch(
                  key: const Key('settings-biometric'),
                  label: 'Face ID or fingerprint',
                  value: ref.watch(biometricUnlockProvider),
                  onChanged: (value) => unawaited(
                    ref
                        .read(biometricUnlockProvider.notifier)
                        .setEnabled(enabled: value),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
