import 'package:backlog_manager/auth/biometric_gate.dart';
import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/light_effects.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/features/appearance/theme_actions.dart';
import 'package:backlog_manager/features/startup/startup_splash.dart';
import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/shell/shell_layout.dart';
import 'package:backlog_manager/shell/shell_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget of the desktop client: the router, the theme, the keyboard
/// shortcuts of the window, the start animation, the switch for the blur and
/// the limit of the system text size ([maxTextScale]).
class BacklogManagerApp extends ConsumerWidget {
  const BacklogManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeSyncProvider);
    final blurEffects =
        ref.watch(blurEffectsProvider) &&
        ref.watch(lightEffectsProvider) == null;
    return MaterialApp.router(
      title: 'Backlog Manager',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(shelfThemeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final touch = !ref.watch(isDesktopProvider);
        final app = AtmosphereSettings(
          blurEnabled: blurEffects,
          child: StartupSplash(
            child: ShellShortcuts(child: child ?? const SizedBox.shrink()),
          ),
        );
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: maxTextScale,
          child: ShelfFormFactor(
            compact: shellLayoutOf(context, ref) == ShellLayout.compact,
            touch: touch,
            child: touch ? _TouchInputs(child: BiometricGate(child: app)) : app,
          ),
        );
      },
    );
  }
}

/// The largest text scale of the system (iOS Dynamic Type, the font size of
/// Android) the app follows: the touch tests check every page up to it, and
/// beyond it the layouts of a phone break.
const maxTextScale = 1.3;

/// Text fields at least [ShelfFormFactor.minTapTarget] high on a touch
/// screen; the theme itself keeps the desktop height.
class _TouchInputs extends StatelessWidget {
  const _TouchInputs({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          constraints: const BoxConstraints(
            minHeight: ShelfFormFactor.minTapTarget,
          ),
        ),
      ),
      child: child,
    );
  }
}
