import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/server_url.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/design/brand_mark.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/banner.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sign-in window: email and password, then the two-factor code for an
/// account that has one. The server in use is shown with a way to change it.
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _email.addListener(_changed);
    _password.addListener(_changed);
    _code.addListener(_changed);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  bool get _canSignIn =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  void _signIn() {
    if (!_canSignIn || ref.read(authControllerProvider).busy) return;
    ref
        .read(authControllerProvider.notifier)
        .login(_email.text.trim(), _password.text);
  }

  void _verify() {
    if (_code.text.trim().isEmpty || ref.read(authControllerProvider).busy) {
      return;
    }
    ref.read(authControllerProvider.notifier).verify(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authControllerProvider);
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final twoFactor = flow.step == LoginStep.twoFactor;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandMark(),
                  const SizedBox(width: 10),
                  Text('Backlog', style: text.section),
                ],
              ),
              const SizedBox(height: 28),
              if (twoFactor) ...[
                Text('Two-factor authentication', style: text.eyebrow),
                const SizedBox(height: 6),
                Text('Verify it is you', style: text.page),
                const SizedBox(height: 6),
                Text(
                  'Enter the 6-digit code from your authenticator app, or one of your backup codes.',
                  style: text.caption.copyWith(color: tokens.muted),
                ),
              ] else ...[
                Text('Sign in', style: text.page),
                const SizedBox(height: 6),
                Text(
                  'Welcome back. Your backlog is waiting.',
                  style: text.caption.copyWith(color: tokens.muted),
                ),
              ],
              const SizedBox(height: 20),
              if (flow.error != null) ...[
                ShelfBanner(message: flow.error!),
                const SizedBox(height: 16),
              ],
              if (twoFactor)
                ..._twoFactorForm(flow)
              else
                ..._passwordForm(flow),
              if (!twoFactor) ...[
                const SizedBox(height: 20),
                const _ServerLine(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _passwordForm(LoginFlow flow) {
    return [
      ShelfField(
        label: 'Email',
        controller: _email,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        onSubmitted: (_) => _passwordFocus.requestFocus(),
      ),
      const SizedBox(height: 14),
      ShelfField(
        label: 'Password',
        controller: _password,
        focusNode: _passwordFocus,
        obscure: true,
        onSubmitted: (_) => _signIn(),
      ),
      const SizedBox(height: 20),
      ShelfButton(
        key: const Key('sign-in-submit'),
        label: flow.busy ? 'Logging in...' : 'Sign in',
        kind: ShelfButtonKind.primary,
        busy: flow.busy,
        onPressed: _canSignIn ? _signIn : null,
      ),
    ];
  }

  List<Widget> _twoFactorForm(LoginFlow flow) {
    return [
      ShelfField(
        label: 'Verification code',
        controller: _code,
        autofocus: true,
        onSubmitted: (_) => _verify(),
      ),
      const SizedBox(height: 20),
      ShelfButton(
        key: const Key('verify-submit'),
        label: flow.busy ? 'Verifying...' : 'Verify',
        kind: ShelfButtonKind.primary,
        busy: flow.busy,
        onPressed: _code.text.trim().isEmpty ? null : _verify,
      ),
      const SizedBox(height: 8),
      ShelfButton(
        label: 'Start over',
        kind: ShelfButtonKind.quiet,
        onPressed: () {
          _code.clear();
          ref.read(authControllerProvider.notifier).startOver();
        },
      ),
    ];
  }
}

/// "Server: host" with the way to change it.
class _ServerLine extends ConsumerWidget {
  const _ServerLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final url = ref.watch(serverUrlProvider).value;
    final uri = url == null ? null : Uri.tryParse(url);
    final host = uri == null
        ? 'not set'
        : uri.hasPort
        ? '${uri.host}:${uri.port}'
        : uri.host;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Server: $host',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.caption.copyWith(color: tokens.faint),
          ),
        ),
        const SizedBox(width: 4),
        ShelfButton(
          label: 'Change',
          kind: ShelfButtonKind.quiet,
          onPressed: () => showShelfSheet<void>(
            context,
            builder: (context) => const _ServerSheet(),
          ),
        ),
      ],
    );
  }
}

class _ServerSheet extends ConsumerStatefulWidget {
  const _ServerSheet();

  @override
  ConsumerState<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<_ServerSheet> {
  final _address = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _address.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await changeServer(
      _address.text,
      store: ref.read(serverUrlStoreProvider),
      adapter: ref.read(serverHealthAdapterProvider),
      onChanged: ref.read(authControllerProvider.notifier).signOut,
    );
    if (!mounted) return;
    if (error == null) {
      ref
        ..invalidate(serverUrlProvider)
        ..invalidate(apiDioProvider);
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShelfSheet(
      title: 'Change the server',
      description: 'The address of the backend this app signs in to.',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: () => Navigator.of(context).maybePop(),
        primary: ShelfButton(
          key: const Key('server-save'),
          label: 'Save',
          kind: ShelfButtonKind.primary,
          busy: _busy,
          onPressed: _address.text.trim().isEmpty ? null : _save,
        ),
      ),
      child: ShelfField(
        key: const Key('server-url-field'),
        label: 'Server address',
        hintText: 'https://api.example.com',
        controller: _address,
        autofocus: true,
        error: _error,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
      ),
    );
  }
}
