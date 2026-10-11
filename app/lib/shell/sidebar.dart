import 'dart:async';

import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/brand_mark.dart';
import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/features/appearance/appearance_page.dart';
import 'package:backlog_manager/features/appearance/theme_actions.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/navigation.dart';
import 'package:backlog_manager/shell/navigation_counts.dart';
import 'package:backlog_manager/shell/pane_widths.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The translucent sidebar, 232 px unless dragged wider or narrower: brand mark, grouped navigation with counts
/// and the account row pinned to the bottom. It collapses to nothing from the
/// title bar.
class Sidebar extends ConsumerWidget {
  const Sidebar({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final animations = !MediaQuery.of(context).disableAnimations;
    final width = ref.watch(paneWidthProvider(Pane.sidebar));

    return AnimatedContainer(
      key: const Key('sidebar'),
      duration: animations ? const Duration(milliseconds: 150) : Duration.zero,
      curve: Curves.easeOut,
      width: collapsed ? 0 : width,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: width,
          maxWidth: width,
          child: ExcludeFocus(
            excluding: collapsed,
            child: ExcludeSemantics(
              excluding: collapsed,
              child: _SidebarContent(location: location),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarContent extends ConsumerWidget {
  const _SidebarContent({required this.location});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final counts = ref.watch(navigationCountsProvider);

    return GlassSurface(
      opacity: 0.52,
      blur: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: const Alignment(0, 0.24),
            colors: [
              tokens.glowSoft.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Brand(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: [
                        for (final section in navigationSections) ...[
                          _SectionLabel(section.label),
                          for (final item in section.items)
                            _NavItem(
                              item: item,
                              active: item.isActiveFor(location),
                              count: counts[item.id],
                            ),
                          if (section.label == 'Personalise')
                            const _ThemeStrip(),
                        ],
                      ],
                    ),
                  ),
                  const _AccountRow(),
                ],
              ),
            ),
            const EdgeLine.fadeFromGlow(axis: Axis.vertical),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          const BrandMark(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Backlog',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).extension<ShelfTextStyles>()!.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!.sidebarLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Text(label.toUpperCase(), style: style),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({required this.item, required this.active, this.count});

  final NavigationItem item;
  final bool active;
  final int? count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final color = active ? tokens.foreground : tokens.muted;

    return Semantics(
      key: Key('nav-${item.id}'),
      button: true,
      selected: active,
      child: InkWell(
        borderRadius: BorderRadius.circular(ShelfRadius.control),
        hoverColor: tokens.glowSoft,
        onTap: () => _activate(context, ref),
        child: Ink(
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShelfRadius.control),
            gradient: active
                ? LinearGradient(colors: [tokens.glowSoft, Colors.transparent])
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 2,
                height: 38,
                child: ColoredBox(
                  color: active ? tokens.accent : Colors.transparent,
                ),
              ),
              const SizedBox(width: 8),
              Icon(item.icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .extension<ShelfTextStyles>()!
                      .navItem
                      .copyWith(color: color),
                ),
              ),
              if (item.id == 'space' && ref.watch(hasSpaceInvitationProvider))
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: DecoratedBox(
                    key: const Key('nav-space-invitation'),
                    decoration: BoxDecoration(
                      color: tokens.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 8, height: 8),
                  ),
                ),
              if (count != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    '$count',
                    style: Theme.of(context)
                        .extension<ShelfTextStyles>()!
                        .label
                        .copyWith(color: tokens.faint),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _activate(BuildContext context, WidgetRef ref) {
    final route = item.route;
    if (route != null) {
      context.go(route);
    } else if (item.action == NavigationAction.addGame) {
      ref.read(addGameRequestProvider.notifier).request();
    }
  }
}

/// The themes as small swatches under "Personalise": a click applies one, the
/// plus opens the theme creator.
class _ThemeStrip extends ConsumerWidget {
  const _ThemeStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final activeId = ref.watch(themeIdProvider);
    final custom = ref.watch(customThemesProvider);

    Widget swatch(String id, String name, ThemeColors colors) {
      final active = id == activeId;
      return Tooltip(
        message: name,
        child: Semantics(
          key: Key('sidebar-theme-$id'),
          button: true,
          selected: active,
          label: name,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => unawaited(_setTheme(context, ref, id)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: active ? tokens.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ThemeSwatch(colors: colors),
            ),
          ),
        ),
      );
    }

    return Padding(
      key: const Key('sidebar-themes'),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final theme in displayThemes)
            swatch(theme.id, theme.name, theme.colors),
          for (final theme in custom)
            swatch(theme.id, theme.name, theme.colors),
          Tooltip(
            message: 'Create a theme',
            child: Semantics(
              key: const Key('sidebar-theme-creator'),
              button: true,
              label: 'Create a theme',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.go(AppRoutes.appearance),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: SizedBox(
                    width: 40,
                    height: 32,
                    child: Icon(Icons.add, size: 18, color: tokens.muted),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _setTheme(BuildContext context, WidgetRef ref, String id) async {
  final error = await ref.read(themeActionsProvider).setTheme(id);
  if (error != null && context.mounted) showShelfToast(context, error);
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final session = ref.watch(sessionProvider);
    final user = session is SessionSignedIn ? session.user : null;
    final name = user?.name ?? '';

    return PopupMenuButton<String>(
      key: const Key('account-row'),
      tooltip: 'Account',
      position: PopupMenuPosition.over,
      offset: const Offset(0, -8),
      onSelected: (value) {
        if (value == 'logout') {
          unawaited(ref.read(authControllerProvider.notifier).signOut());
        } else if (value == 'settings') {
          context.go(AppRoutes.settings);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'settings',
          height: 40,
          child: Text('Settings'),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          height: 40,
          child: Text('Log out'),
        ),
      ],
      child: SizedBox(
        height: 58,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tokens.borderSubtle)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _Avatar(initial: name.isEmpty ? '?' : name[0].toUpperCase()),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: text.control.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tokens.foreground,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: text.label.copyWith(
                          fontWeight: FontWeight.w400,
                          color: tokens.faint,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more, size: 16, color: tokens.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.accentA, tokens.accentB],
        ),
        boxShadow: [
          BoxShadow(color: tokens.glowSoft, spreadRadius: 2),
          BoxShadow(color: tokens.accentGlow, blurRadius: 14),
        ],
      ),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Text(
            initial,
            style: Theme.of(context)
                .extension<ShelfTextStyles>()!
                .label
                .copyWith(fontWeight: FontWeight.w800, color: tokens.onAccent),
          ),
        ),
      ),
    );
  }
}
