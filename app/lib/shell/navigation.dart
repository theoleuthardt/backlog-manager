import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';

/// What a navigation item does when it is not a page of the router.
enum NavigationAction { addGame }

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
        label: 'Shared space',
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
        label: 'Add game',
        icon: Icons.add_circle_outline,
        action: NavigationAction.addGame,
      ),
      NavigationItem(
        id: 'steam',
        label: 'Steam sync',
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
    ],
  ),
];
