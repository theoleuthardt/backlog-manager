import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
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
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final enabled = user.isTwoFactorEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Security', style: style.page.copyWith(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                'Protect your account.',
                style: style.caption.copyWith(color: tokens.muted),
              ),
            ],
          ),
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
