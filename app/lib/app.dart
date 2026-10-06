import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/shell/shell_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget of the desktop client: the router, the theme and the keyboard
/// shortcuts of the window.
class BacklogManagerApp extends ConsumerWidget {
  const BacklogManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Backlog Manager',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(shelfThemeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          ShellShortcuts(child: child ?? const SizedBox.shrink()),
    );
  }
}
