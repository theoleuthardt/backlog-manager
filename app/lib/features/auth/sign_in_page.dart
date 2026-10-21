import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/server_url.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/design/brand_mark.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/banner.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/sanitize.dart';
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
  bool _emailRefused = false;

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

  String? get _emailError =>
      _emailRefused && !looksLikeEmail(_email.text.trim())
      ? 'Enter a valid email address'
      : null;

  void _signIn() {
    if (!_canSignIn || ref.read(authControllerProvider).busy) return;
    if (!looksLikeEmail(_email.text.trim())) {
      setState(() => _emailRefused = true);
      return;
    }
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
        padding: const EdgeInsets.all(32),
        child: _AuthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandMark(size: 46),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      twoFactor
                          ? 'Two-factor authentication'
                          : 'Backlog Manager',
                      style: text.page.copyWith(color: tokens.accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                twoFactor ? 'Verify it is you' : 'Sign in',
                style: text.hero,
              ),
              const SizedBox(height: 8),
              Text(
                twoFactor
                    ? 'Enter the 6-digit code from your authenticator app, or '
                          'one of your backup codes.'
                    : 'Welcome back. Your backlog is waiting.',
                style: text.body.copyWith(color: tokens.muted),
              ),
              const SizedBox(height: 28),
              if (flow.error != null) ...[
                ShelfBanner(message: flow.error!),
                const SizedBox(height: 18),
              ],
              if (twoFactor)
                ..._twoFactorForm(flow)
              else
                ..._passwordForm(flow),
              if (!twoFactor) ...[
                const SizedBox(height: 28),
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
        error: _emailError,
        controller: _email,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        onSubmitted: (_) => _passwordFocus.requestFocus(),
      ),
      const SizedBox(height: 18),
      ShelfField(
        label: 'Password',
        controller: _password,
        focusNode: _passwordFocus,
        obscure: true,
        onSubmitted: (_) => _signIn(),
      ),
      const SizedBox(height: 26),
      ShelfButton(
        key: const Key('sign-in-submit'),
        label: flow.busy ? 'Logging in...' : 'Sign in',
        kind: ShelfButtonKind.primary,
        expanded: true,
        busy: flow.busy,
        onPressed: _canSignIn ? _signIn : null,
      ),
    ];
  }

  List<Widget> _twoFactorForm(LoginFlow flow) {
    return [
      ShelfField(
        label: 'Verification Code',
        controller: _code,
        autofocus: true,
        onSubmitted: (_) => _verify(),
      ),
      const SizedBox(height: 26),
      ShelfButton(
        key: const Key('verify-submit'),
        label: flow.busy ? 'Verifying...' : 'Verify',
        kind: ShelfButtonKind.primary,
        expanded: true,
        busy: flow.busy,
        onPressed: _code.text.trim().isEmpty ? null : _verify,
      ),
      const SizedBox(height: 8),
      ShelfButton(
        label: 'Start Over',
        kind: ShelfButtonKind.quiet,
        onPressed: () {
          _code.clear();
          ref.read(authControllerProvider.notifier).startOver();
        },
      ),
    ];
  }
}

/// The card of the sign-in window: the surface of the design with its glow,
/// 480 px wide.
class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return Container(
      key: const Key('auth-card'),
      width: 480,
      padding: const EdgeInsets.fromLTRB(44, 40, 44, 32),
      decoration: BoxDecoration(
        color: atOpacity(tokens.surface, 0.82),
        borderRadius: BorderRadius.circular(ShelfRadius.dialog + 4),
        border: Border.all(color: tokens.borderStrong),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 90,
            offset: const Offset(0, 30),
          ),
          BoxShadow(color: tokens.glowSoft, blurRadius: 70),
        ],
      ),
      child: child,
    );
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
        label: 'Server Address',
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
