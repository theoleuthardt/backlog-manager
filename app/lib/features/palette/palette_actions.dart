import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/navigation.dart';
import 'package:backlog_manager/shell/palette_registry.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registers the actions of the window itself: Add game, Open settings, a "Go
/// to" action for every screen of the sidebar and one per built-in theme.
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

  for (final theme in builtinThemes) {
    registry.register(
      PaletteAction(
        id: 'theme-${theme.id}',
        label: 'Switch theme to ${theme.name}',
        run: () => ref.read(themeIdProvider.notifier).select(theme.id),
      ),
    );
  }
}
