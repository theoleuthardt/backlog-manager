import 'dart:async';

import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/features/appearance/theme_actions.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/navigation.dart';
import 'package:backlog_manager/shell/palette_registry.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registers the actions of the window itself: Add game, Open settings, a "Go
/// to" action for every screen of the sidebar and one per theme, the
/// built-in ones and the user's own.
/// Registering again replaces the actions in place, so it may run whenever the
/// window is built. Features add theirs the same way, through
/// [paletteRegistryProvider].
void registerShellPaletteActions(ProviderContainer ref) {
  final registry = ref.read(paletteRegistryProvider.notifier);
  final router = ref.read(routerProvider);

  registry
    ..register(
      PaletteAction(
        id: 'add-game',
        label: 'Add game',
        shortcut: const PaletteShortcut(LogicalKeyboardKey.keyN),
        run: () => ref.read(addGameRequestProvider.notifier).request(),
      ),
    )
    ..register(
      PaletteAction(
        id: 'sync-igdb',
        label: 'Sync IGDB game data',
        shortcut: const PaletteShortcut(LogicalKeyboardKey.keyI, shift: true),
        run: () => ref.read(igdbSyncRequestProvider.notifier).request(),
      ),
    )
    ..register(
      PaletteAction(
        id: 'open-settings',
        label: 'Open settings',
        shortcut: const PaletteShortcut(LogicalKeyboardKey.comma),
        run: () => router.go(AppRoutes.settings),
      ),
    );

  for (final section in navigationSections) {
    for (final item in section.items) {
      final route = item.route;
      if (route == null || route == AppRoutes.settings) continue;
      registry.register(
        PaletteAction(
          id: 'go-${item.id}',
          label: 'Go to ${item.label}',
          run: () => router.go(route),
        ),
      );
    }
  }

  PaletteAction switchTo(String id, String name) => PaletteAction(
    id: 'theme-$id',
    label: 'Switch theme to $name',
    run: () => unawaited(ref.read(themeActionsProvider).setTheme(id)),
  );

  for (final theme in builtinThemes) {
    registry.register(switchTo(theme.id, theme.name));
  }

  var registered = <String>{};
  ref.listen(customThemesProvider, (_, themes) {
    final ids = {for (final theme in themes) 'theme-${theme.id}'};
    for (final stale in registered.difference(ids)) {
      registry.unregister(stale);
    }
    for (final theme in themes) {
      registry.register(switchTo(theme.id, theme.name));
    }
    registered = ids;
  }, fireImmediately: true);
}
