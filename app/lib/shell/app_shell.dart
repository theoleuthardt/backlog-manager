import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/features/inspector/entry_inspector.dart';
import 'package:backlog_manager/features/library/wishlist_sync_prompt.dart';
import 'package:backlog_manager/features/palette/command_palette.dart';
import 'package:backlog_manager/routing/routes.dart';
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
      } else if (_showingEntry) {
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(shellStatusProvider.notifier).clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspector = ref.watch(shellInspectorProvider);
    final location = widget.location;
    ref.listen(shellInspectorProvider, (_, next) {
      if (next == null && _showingEntry && widget.entryId != null) {
        context.go(widget.location);
      }
    });

    return PaletteHost(
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
                    Expanded(
                      child: SizedBox.expand(
                        key: const Key('main-content'),
                        child: WishlistSyncPrompt(child: widget.child),
                      ),
                    ),
                    if (inspector != null) _InspectorSlot(child: inspector),
                  ],
                ),
              ),
              const StatusBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectorSlot extends StatelessWidget {
  const _InspectorSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('inspector'),
      width: 380,
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
/// title bar and atmosphere around one page.
class FullWindowFrame extends StatelessWidget {
  const FullWindowFrame({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PaletteHost(
      child: Material(
        type: MaterialType.transparency,
        child: AtmosphereBackground(
          child: Column(
            children: [
              TitleBar(
                location: location,
                minimal: location != AppRoutes.settings,
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
