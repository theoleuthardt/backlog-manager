import 'dart:async';

import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/features/shortcuts/shortcuts_sheet.dart';
import 'package:backlog_manager/routing/history.dart';
import 'package:backlog_manager/shell/navigation.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:backlog_manager/shell/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

const _primaryIds = ['home', 'library', 'add-game', 'space'];

/// The items of the bottom bar and the rail; every other item is behind
/// "More", in the [NavigationDrawerPanel].
final List<NavigationItem> primaryNavigationItems = [
  for (final id in _primaryIds)
    navigationSections
        .expand((section) => section.items)
        .firstWhere((item) => item.id == id),
];

/// The top bar of a phone or handheld: back, the page title and the counts
/// the page reports. It replaces the title bar and the status bar, which have
/// no place on a small screen. A [minimal] bar (sign-in, setup) has the title
/// only.
class MobileTopBar extends ConsumerWidget {
  const MobileTopBar({required this.location, this.minimal = false, super.key});

  final String location;
  final bool minimal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final history = ref.watch(navigationHistoryProvider);
    final counts = ref.watch(shellStatusProvider).counts;

    return SizedBox(
      key: const Key('mobile-top-bar'),
      height: 52,
      child: GlassSurface(
        opacity: 0.42,
        blur: 14,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  if (!minimal && history.canGoBack)
                    IconButton(
                      key: const Key('nav-back'),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      tooltip: 'Back',
                      color: tokens.muted,
                      onPressed: () {
                        final target = ref
                            .read(navigationHistoryProvider.notifier)
                            .back();
                        if (target != null) context.go(target);
                      },
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pageTitle(location),
                      key: const Key('mobile-top-bar-title'),
                      style: text.windowTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (counts != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        counts,
                        style: text.label.copyWith(
                          color: tokens.muted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            const EdgeLine.glowInMiddle(axis: Axis.horizontal),
          ],
        ),
      ),
    );
  }
}

/// The bottom bar of a phone in portrait: the [primaryNavigationItems] and
/// More.
class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({required this.location, required this.onMore, super.key});

  final String location;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    return DecoratedBox(
      key: const Key('bottom-nav'),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.borderSubtle)),
      ),
      child: GlassSurface(
        opacity: 0.52,
        blur: 14,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (final item in primaryNavigationItems)
                  Expanded(
                    child: _Destination(
                      key: Key('bottom-nav-${item.id}'),
                      icon: item.icon,
                      label: _shortLabel(item),
                      active: item.isActiveFor(location),
                      onTap: () => activateNavigationItem(context, ref, item),
                    ),
                  ),
                Expanded(
                  child: _Destination(
                    key: const Key('nav-more'),
                    icon: Icons.menu,
                    label: 'More',
                    active: false,
                    onTap: onMore,
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

/// The rail of a phone in landscape, the handhelds and a tablet in portrait:
/// the [primaryNavigationItems] and More, on the left edge where the height
/// is short.
class ShellNavRail extends ConsumerWidget {
  const ShellNavRail({required this.location, required this.onMore, super.key});

  final String location;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      key: const Key('nav-rail'),
      width: 76,
      child: GlassSurface(
        opacity: 0.52,
        blur: 10,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final item in primaryNavigationItems)
                      SizedBox(
                        height: 60,
                        child: _Destination(
                          key: Key('rail-${item.id}'),
                          icon: item.icon,
                          label: _shortLabel(item),
                          active: item.isActiveFor(location),
                          onTap: () =>
                              activateNavigationItem(context, ref, item),
                        ),
                      ),
                    SizedBox(
                      height: 60,
                      child: _Destination(
                        key: const Key('nav-more'),
                        icon: Icons.menu,
                        label: 'More',
                        active: false,
                        onTap: onMore,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const EdgeLine.fadeFromGlow(axis: Axis.vertical),
          ],
        ),
      ),
    );
  }
}

String _shortLabel(NavigationItem item) => switch (item.id) {
  'space' => 'Space',
  'add-game' => 'Add',
  _ => item.label,
};

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final color = active ? tokens.accent : tokens.muted;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        hoverColor: tokens.glowSoft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.caption.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The whole sidebar (every item, the themes and the account) as the drawer
/// behind More; choosing an item closes it.
class NavigationDrawerPanel extends StatelessWidget {
  const NavigationDrawerPanel({
    required this.location,
    required this.onItemSelected,
    super.key,
  });

  final String location;
  final VoidCallback onItemSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return Drawer(
      key: const Key('nav-drawer'),
      width: 300,
      backgroundColor: tokens.background,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        right: false,
        child: SidebarContent(
          location: location,
          onItemSelected: onItemSelected,
        ),
      ),
    );
  }
}
