import 'package:backlog_manager/auth/sign_in_failure.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the details of a failed sign-in.
Future<void> showSignInFailureSheet(
  BuildContext context,
  SignInFailure failure,
) => showShelfSheet<void>(
  context,
  builder: (_) => SignInFailureSheet(failure: failure),
);

/// What went wrong and what to do, the technical details line and a button
/// that copies all of it, so it can be sent to whoever runs the server.
class SignInFailureSheet extends StatelessWidget {
  const SignInFailureSheet({required this.failure, super.key});

  final SignInFailure failure;

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: failure.report));
      if (context.mounted) showShelfToast(context, 'Details copied');
    } on Object {
      if (context.mounted) {
        showShelfToast(context, 'Could not copy the details. Select them.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return ShelfSheet(
      title: failure.title,
      description: failure.explanation,
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        cancelLabel: 'Close',
        onCancel: () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('sign-in-failure-copy'),
          label: 'Copy details',
          icon: Icons.copy,
          kind: ShelfButtonKind.primary,
          onPressed: () => _copy(context),
        ),
      ),
      child: switch (failure.details) {
        final details? => SelectableText(
          details,
          key: const Key('sign-in-failure-details'),
          style: text.caption.copyWith(color: tokens.muted),
        ),
        null => const SizedBox.shrink(),
      },
    );
  }
}
