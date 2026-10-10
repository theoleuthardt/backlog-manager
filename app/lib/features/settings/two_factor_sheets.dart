import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/two_factor_api.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Reads the account again after two-factor authentication was switched. The
/// change is already made on the server, so a failure here is not reported
/// next to its result: the account is read again with the next request.
Future<void> _refreshAccount(AuthController auth) async {
  try {
    await auth.refreshUser();
  } on Object {
    return;
  }
}

/// Opens the setup of two-factor authentication.
Future<void> showEnrollTwoFactorSheet(BuildContext context) {
  return showShelfSheet<void>(
    context,
    builder: (_) => const EnrollTwoFactorSheet(),
  );
}

/// Opens the confirmation that turns two-factor authentication off.
Future<void> showDisableTwoFactorSheet(BuildContext context) {
  return showShelfSheet<void>(
    context,
    builder: (_) => const DisableTwoFactorSheet(),
  );
}

enum _EnrollStep { code, backupCodes }

/// Two steps: the QR code with the manual key and a field for the first code
/// of the authenticator, then the backup codes, which are shown once.
class EnrollTwoFactorSheet extends ConsumerStatefulWidget {
  const EnrollTwoFactorSheet({super.key});

  @override
  ConsumerState<EnrollTwoFactorSheet> createState() =>
      _EnrollTwoFactorSheetState();
}

class _EnrollTwoFactorSheetState extends ConsumerState<EnrollTwoFactorSheet> {
  final _code = TextEditingController();
  TwoFactorEnrollment? _enrollment;
  List<String> _backupCodes = const [];
  _EnrollStep _step = _EnrollStep.code;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final enrollment = await ref.read(twoFactorApiProvider).enroll();
      if (mounted) setState(() => _enrollment = enrollment);
    } on Object catch (error) {
      if (!mounted) return;
      showShelfToast(
        context,
        ApiException.from(error, 'Failed to start two-factor setup').message,
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      final codes = await ref.read(twoFactorApiProvider).verify(_code.text);
      if (!mounted) return;
      setState(() {
        _backupCodes = codes;
        _step = _EnrollStep.backupCodes;
        _verifying = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _verifying = false);
      showShelfToast(
        context,
        ApiException.from(error, 'Invalid two-factor code').message,
      );
      return;
    }
    await _refreshAccount(auth);
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _backupCodes.join('\n')));
      if (mounted) showShelfToast(context, 'Backup codes copied to clipboard');
    } on Object {
      if (mounted) {
        showShelfToast(
          context,
          'Could not copy the backup codes. Copy them manually.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _step == _EnrollStep.code ? _codeStep(context) : _codesStep(context);
  }

  Widget _codeStep(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final enrollment = _enrollment;
    return ShelfSheet(
      title: 'Set up two-factor authentication',
      description:
          'Scan the QR code with your authenticator app, then enter the '
          '6-digit code it shows.',
      width: ShelfSheetWidth.compact,
      footer: Align(
        alignment: Alignment.centerRight,
        child: ShelfButton(
          key: const Key('two-factor-verify'),
          label: _verifying ? 'Verifying...' : 'Verify and enable',
          kind: ShelfButtonKind.primary,
          busy: _verifying,
          onPressed: enrollment == null || _code.text.trim().isEmpty
              ? null
              : _verify,
        ),
      ),
      child: enrollment == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Generating your secret...',
                  key: const Key('two-factor-generating'),
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        key: const Key('two-factor-qr'),
                        data: enrollment.otpauthUrl,
                        size: 176,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Can't scan it? Enter this code manually",
                  style: style.caption.copyWith(color: tokens.muted),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  enrollment.secret,
                  key: const Key('two-factor-secret'),
                  style: style.fieldText.copyWith(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 14),
                ShelfField(
                  label: '6-digit code',
                  hintText: '123456',
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (_code.text.trim().isNotEmpty && !_verifying) {
                      _verify();
                    }
                  },
                ),
              ],
            ),
    );
  }

  Widget _codesStep(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return ShelfSheet(
      title: 'Save your backup codes',
      description:
          'Store these somewhere safe. Each code can be used once to sign in '
          "if you lose access to your authenticator app. They won't be shown "
          'again.',
      width: ShelfSheetWidth.compact,
      footer: Row(
        children: [
          ShelfButton(
            key: const Key('two-factor-copy'),
            label: 'Copy codes',
            onPressed: _copy,
          ),
          const Spacer(),
          ShelfButton(
            key: const Key('two-factor-done'),
            label: 'Done',
            kind: ShelfButtonKind.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            key: const Key('two-factor-codes'),
            spacing: 24,
            runSpacing: 8,
            children: [
              for (final code in _backupCodes)
                SizedBox(
                  width: 130,
                  child: Text(
                    code,
                    style: style.fieldText.copyWith(fontFamily: 'monospace'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for the password before two-factor authentication is turned off, and
/// says that the backup codes stop working.
class DisableTwoFactorSheet extends ConsumerStatefulWidget {
  const DisableTwoFactorSheet({super.key});

  @override
  ConsumerState<DisableTwoFactorSheet> createState() =>
      _DisableTwoFactorSheetState();
}

class _DisableTwoFactorSheetState extends ConsumerState<DisableTwoFactorSheet> {
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      await ref.read(twoFactorApiProvider).disable(_password.text);
      if (!mounted) return;
      showShelfToast(context, 'Two-factor authentication disabled');
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showShelfToast(
        context,
        ApiException.from(
          error,
          'Failed to disable two-factor authentication',
        ).message,
      );
      return;
    }
    await _refreshAccount(auth);
  }

  @override
  Widget build(BuildContext context) {
    return ShelfSheet(
      title: 'Disable two-factor authentication?',
      description:
          'Enter your password to confirm. Your backup codes will stop '
          'working.',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: _busy ? null : () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('two-factor-disable-confirm'),
          label: _busy ? 'Disabling...' : 'Disable',
          kind: ShelfButtonKind.danger,
          busy: _busy,
          onPressed: _password.text.isEmpty ? null : _disable,
        ),
      ),
      child: ShelfField(
        label: 'Password',
        controller: _password,
        obscure: true,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (_password.text.isNotEmpty && !_busy) _disable();
        },
      ),
    );
  }
}
