import 'dart:async';

import 'package:backlog_manager/features/shortcuts/shortcuts_sheet.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What a navigation item does when it is not a page of the router.
enum NavigationAction { addGame, shortcuts }

class NavigationItem {
  const NavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    this.route,
    this.action,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? route;
  final NavigationAction? action;

  /// Whether this item is the one to highlight for the current [location].
  bool isActiveFor(String location) {
    final route = this.route;
    if (route == null) return false;
    if (route == AppRoutes.home) return location == route;
    return location == route || location.startsWith('$route/');
  }
}

class NavigationSection {
  const NavigationSection({required this.label, required this.items});

  final String label;
  final List<NavigationItem> items;
}

const navigationSections = [
  NavigationSection(
    label: 'Backlog',
    items: [
      NavigationItem(
        id: 'home',
        label: 'Home',
        icon: Icons.home_outlined,
        route: AppRoutes.home,
      ),
      NavigationItem(
        id: 'library',
        label: 'Library',
        icon: Icons.grid_view_outlined,
        route: AppRoutes.library,
      ),
      NavigationItem(
        id: 'space',
        label: 'Shared Space',
        icon: Icons.group_outlined,
        route: AppRoutes.space,
      ),
    ],
  ),
  NavigationSection(
    label: 'Add',
    items: [
      NavigationItem(
        id: 'add-game',
        label: 'Add Game',
        icon: Icons.add_circle_outline,
        action: NavigationAction.addGame,
      ),
      NavigationItem(
        id: 'steam',
        label: 'Steam Sync',
        icon: Icons.sync_outlined,
        route: AppRoutes.steam,
      ),
      NavigationItem(
        id: 'import',
        label: 'Import CSV',
        icon: Icons.file_upload_outlined,
        route: AppRoutes.import,
      ),
      NavigationItem(
        id: 'export',
        label: 'Export CSV',
        icon: Icons.file_download_outlined,
        route: AppRoutes.export,
      ),
    ],
  ),
  NavigationSection(
    label: 'Personalise',
    items: [
      NavigationItem(
        id: 'appearance',
        label: 'Appearance',
        icon: Icons.palette_outlined,
        route: AppRoutes.appearance,
      ),
      NavigationItem(
        id: 'settings',
        label: 'Settings',
        icon: Icons.settings_outlined,
        route: AppRoutes.settings,
      ),
      NavigationItem(
        id: 'shortcuts',
        label: 'Shortcuts',
        icon: Icons.keyboard_outlined,
        action: NavigationAction.shortcuts,
      ),
    ],
  ),
];

const _pageTitles = {
  AppRoutes.creationTool: 'Creation Tool',
  AppRoutes.setup: 'Setup',
  AppRoutes.signIn: 'Sign in',
  AppRoutes.loading: 'Loading',
};

/// The title shown in the title bar for the page at [location].
String pageTitle(String location) {
  for (final section in navigationSections) {
    for (final item in section.items) {
      if (item.isActiveFor(location)) return item.label;
    }
  }
  return _pageTitles[location] ?? 'Backlog Manager';
}

/// What [item] does when it is chosen, in the sidebar, the bottom bar or the
/// rail: a page of the router, a new game, or the shortcuts sheet.
void activateNavigationItem(
  BuildContext context,
  WidgetRef ref,
  NavigationItem item,
) {
  final route = item.route;
  if (route != null) {
    context.go(route);
  } else if (item.action == NavigationAction.addGame) {
    ref.read(addGameRequestProvider.notifier).request();
  } else if (item.action == NavigationAction.shortcuts) {
    unawaited(showShortcutsSheet(context));
  }
}
