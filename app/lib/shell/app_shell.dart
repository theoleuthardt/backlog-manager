import 'dart:async';

import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/features/inspector/entry_inspector.dart';
import 'package:backlog_manager/features/library/wishlist_sync_prompt.dart';
import 'package:backlog_manager/features/palette/command_palette.dart';
import 'package:backlog_manager/features/updates/update_notifier.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/gamepad.dart';
import 'package:backlog_manager/shell/gamepad_hints.dart';
import 'package:backlog_manager/shell/mobile_navigation.dart';
import 'package:backlog_manager/shell/pane_widths.dart';
import 'package:backlog_manager/shell/search_hint.dart';
import 'package:backlog_manager/shell/shell_layout.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:backlog_manager/shell/sidebar.dart';
import 'package:backlog_manager/shell/status_bar.dart';
import 'package:backlog_manager/shell/title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The main window: title bar, then the sidebar and the main pane with the
/// inspector slot on its right, then the status bar, all over the atmosphere.
/// The [child] is the page of the current route. The counts of the status bar
/// belong to a page, so they are cleared when the route changes and the new
/// page reports its own. The `entry` of the address (`/library?entry=7`)
/// opens the inspector of that game in the slot; closing the inspector takes
/// it from the address again.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    required this.location,
    required this.child,
    this.entryId,
    super.key,
  });

  final String location;
  final int? entryId;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _slotKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mainKey = GlobalKey();
  bool _showingEntry = false;

  @override
  void initState() {
    super.initState();
    _syncInspector();
  }

  void _syncInspector() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final inspector = ref.read(shellInspectorProvider.notifier);
      final id = widget.entryId;
      if (id != null) {
        _showingEntry = true;
        inspector.show(EntryInspector(entryId: id));
      } else {
        _showingEntry = false;
        inspector.hide();
      }
    });
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryId != widget.entryId) _syncInspector();
    if (oldWidget.location != widget.location) {
      _scaffoldKey.currentState?.closeDrawer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(shellStatusProvider.notifier).clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = shellLayoutOf(context, ref);
    final inspector = ref.watch(shellInspectorProvider);
    final fullscreen =
        inspector != null &&
        (layout != ShellLayout.expanded ||
            ref.watch(inspectorFullscreenProvider));
    final location = widget.location;
    final slot = inspector == null
        ? null
        : KeyedSubtree(
            key: _slotKey,
            child: _InspectorSlot(fullscreen: fullscreen, child: inspector),
          );
    ref.listen(shellInspectorProvider, (_, next) {
      if (next == null) {
        ref.read(inspectorFullscreenProvider.notifier).exit();
        if (_showingEntry && widget.entryId != null) {
          context.go(widget.location);
        }
      }
    });

    final mainArea = Stack(
      key: _mainKey,
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: fullscreen,
          child: SizedBox.expand(
            key: const Key('main-content'),
            child: UpdateNotifier(
              child: WishlistSyncPrompt(
                child: SearchHintPrompt(
                  location: location,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
        if (slot != null && fullscreen) Positioned.fill(child: slot),
      ],
    );

    if (layout != ShellLayout.expanded) {
      return _MobileShell(
        scaffoldKey: _scaffoldKey,
        location: location,
        layout: layout,
        child: mainArea,
      );
    }

    final window = PaletteHost(
      child: Material(
        type: MaterialType.transparency,
        child: AtmosphereBackground(
          child: Column(
            children: [
              TitleBar(location: location),
              Expanded(
                child: Row(
                  children: [
                    Sidebar(location: location),
                    if (!ref.watch(sidebarCollapsedProvider))
                      const PaneResizeHandle(
                        pane: Pane.sidebar,
                        growsToRight: true,
                      ),
                    Expanded(child: mainArea),
                    if (slot != null && !fullscreen) ...[
                      const PaneResizeHandle(
                        pane: Pane.inspector,
                        growsToRight: false,
                      ),
                      slot,
                    ],
                  ],
                ),
              ),
              const StatusBar(),
            ],
          ),
        ),
      ),
    );
    return ShelfFormFactor.isTouch(context)
        ? SystemBackHandler(child: window)
        : window;
  }
}

/// The main window on a phone or handheld: the [MobileTopBar] over the page,
/// a [BottomNavBar] below it in [ShellLayout.compact] or a [ShellNavRail]
/// beside it in [ShellLayout.medium], and the whole sidebar as the drawer
/// behind More. The safe areas keep it clear of the notch, the Dynamic Island,
/// the home indicator and rounded corners.
class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.scaffoldKey,
    required this.location,
    required this.layout,
    required this.child,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final String location;
  final ShellLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = layout == ShellLayout.compact;
    void openMore() => unawaited(showMoreSheet(context, location: location));

    return SystemBackHandler(
      child: PaletteHost(
        child: AtmosphereBackground(
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: Colors.transparent,
            bottomNavigationBar: compact
                ? BottomNavBar(location: location, onMore: openMore)
                : null,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!compact)
                  ShellNavRail(location: location, onMore: openMore),
                Expanded(
                  child: SafeArea(
                    left: compact,
                    bottom: !compact,
                    child: Column(
                      children: [
                        MobileTopBar(location: location),
                        Expanded(child: child),
                        const GamepadHints(),
                      ],
                    ),
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

class _InspectorSlot extends ConsumerWidget {
  const _InspectorSlot({required this.child, this.fullscreen = false});

  final Widget child;
  final bool fullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      key: const Key('inspector'),
      width: fullscreen ? null : ref.watch(paneWidthProvider(Pane.inspector)),
      child: GlassSurface(
        opacity: 0.52,
        blur: 10,
        child: Row(
          children: [
            const EdgeLine.fadeFromGlow(axis: Axis.vertical),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// A window without a sidebar (sign-in, the setup wizard, settings): the same
/// title bar and atmosphere around one page; on a phone or handheld the
/// [MobileTopBar] (with back in settings) inside the safe areas. On a touch
/// screen the page stays above the on-screen keyboard, which this frame,
/// unlike the `Scaffold` of the main shell, would otherwise leave on top of
/// it.
class FullWindowFrame extends ConsumerWidget {
  const FullWindowFrame({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minimal = location != AppRoutes.settings;
    if (shellLayoutOf(context, ref) != ShellLayout.expanded) {
      return SystemBackHandler(
        child: PaletteHost(
          child: Material(
            type: MaterialType.transparency,
            child: AtmosphereBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    MobileTopBar(location: location, minimal: minimal),
                    Expanded(child: _AboveKeyboard(child: child)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final window = PaletteHost(
      child: Material(
        type: MaterialType.transparency,
        child: AtmosphereBackground(
          child: Column(
            children: [
              TitleBar(location: location, minimal: minimal),
              Expanded(
                child: ShelfFormFactor.isTouch(context)
                    ? _AboveKeyboard(child: child)
                    : child,
              ),
            ],
          ),
        ),
      ),
    );
    return ShelfFormFactor.isTouch(context)
        ? SystemBackHandler(child: window)
        : window;
  }
}

/// Keeps [child] above the on-screen keyboard and closes the keyboard on a
/// tap next to a field: the number pad of iOS has no key that closes it.
class _AboveKeyboard extends StatelessWidget {
  const _AboveKeyboard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: child,
      ),
    );
  }
}
