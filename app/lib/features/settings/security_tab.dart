import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/features/settings/settings_widgets.dart';
import 'package:backlog_manager/features/settings/two_factor_sheets.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';

/// The security settings: two-factor authentication with an authenticator
/// app, which is set up with a QR code and turned off with the password.
class SecurityTab extends StatelessWidget {
  const SecurityTab({required this.user, super.key});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}
