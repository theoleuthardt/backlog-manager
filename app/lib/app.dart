import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/features/appearance/theme_actions.dart';
import 'package:backlog_manager/features/startup/startup_splash.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/shell/shell_layout.dart';
import 'package:backlog_manager/shell/shell_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget of the desktop client: the router, the theme, the keyboard
/// shortcuts of the window, the start animation and the switch for the blur.
class BacklogManagerApp extends ConsumerWidget {
  const BacklogManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeSyncProvider);
    final blurEffects = ref.watch(blurEffectsProvider);
    return MaterialApp.router(
      title: 'Backlog Manager',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(shelfThemeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => ShelfFormFactor(
        compact: shellLayoutOf(context, ref) == ShellLayout.compact,
        child: AtmosphereSettings(
          blurEnabled: blurEffects,
          child: StartupSplash(
            child: ShellShortcuts(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
