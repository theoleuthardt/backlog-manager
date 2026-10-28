import 'dart:async';

import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/biometric_lock.dart';
import 'package:backlog_manager/design/brand_mark.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lays the lock screen over the app while [biometricUnlockProvider] is on,
/// the user is signed in and [appLockedProvider] is closed. The app stays
/// mounted below (its
/// pages keep their state) but takes no input and is hidden from the
/// screen reader. It also tells the lock when the app goes to the background
/// and comes back.
class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(appLockedProvider.notifier).hidden(DateTime.now()),
      onShow: () => ref.read(appLockedProvider.notifier).shown(DateTime.now()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(biometricUnlockProvider);
    final signedIn = ref.watch(sessionProvider) is SessionSignedIn;
    final locked = ref.watch(appLockedProvider);
    final covered = signedIn && enabled && locked;

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: covered,
          child: ExcludeSemantics(
            excluding: covered,
            child: IgnorePointer(ignoring: covered, child: widget.child),
          ),
        ),
        if (covered) const _LockScreen(),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  var _asked = false;

  void _askOnce() {
    if (_asked) return;
    _asked = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(ref.read(appLockedProvider.notifier).tryUnlock()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    _askOnce();

    return ColoredBox(
      key: const Key('biometric-lock'),
      color: tokens.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 56),
                const SizedBox(height: 18),
                Text(
                  'Backlog Manager is locked',
                  textAlign: TextAlign.center,
                  style: text.section,
                ),
                const SizedBox(height: 22),
                ShelfButton(
                  key: const Key('biometric-unlock'),
                  label: 'Unlock',
                  icon: Icons.fingerprint,
                  kind: ShelfButtonKind.primary,
                  onPressed: () => unawaited(
                    ref.read(appLockedProvider.notifier).tryUnlock(),
                  ),
                ),
                const SizedBox(height: 8),
                ShelfButton(
                  key: const Key('biometric-sign-out'),
                  label: 'Sign out',
                  kind: ShelfButtonKind.quiet,
                  onPressed: () => unawaited(
                    ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
