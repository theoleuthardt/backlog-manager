import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/design/glass.dart';
import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/routing/history.dart';
import 'package:backlog_manager/shell/navigation.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:backlog_manager/shell/window_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _macTrafficLights = 80.0;

/// The 52 px title bar: sidebar toggle, back and forward, the page title and
/// the search field with its shortcut hint. It is the drag region of the
/// window; Windows and Linux get caption buttons on the right, macOS keeps its
/// native traffic lights on the left. A [minimal] bar (sign-in, setup) has the
/// title only.
class TitleBar extends ConsumerWidget {
  const TitleBar({required this.location, this.minimal = false, super.key});

  final String location;
  final bool minimal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final controls = ref.watch(windowControlsProvider);
    final history = ref.watch(navigationHistoryProvider);

    return SizedBox(
      key: const Key('title-bar'),
      height: 52,
      child: GlassSurface(
        opacity: 0.42,
        blur: 14,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      key: const Key('title-bar-drag'),
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) => controls.startDragging(),
                      onDoubleTap: controls.toggleMaximize,
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(width: isMac ? _macTrafficLights : 20),
                      if (!minimal) ...[
                        _BarButton(
                          key: const Key('sidebar-toggle'),
                          icon: Icons.view_sidebar_outlined,
                          tooltip: 'Show or hide the sidebar',
                          onPressed: ref
                              .read(sidebarCollapsedProvider.notifier)
                              .toggle,
                        ),
                        const SizedBox(width: 4),
                        _BarButton(
                          key: const Key('nav-back'),
                          icon: Icons.arrow_back_ios_new,
                          iconSize: 14,
                          tooltip: 'Back',
                          onPressed: history.canGoBack
                              ? () => _go(
                                  context,
                                  ref
                                      .read(navigationHistoryProvider.notifier)
                                      .back(),
                                )
                              : null,
                        ),
                        _BarButton(
                          key: const Key('nav-forward'),
                          icon: Icons.arrow_forward_ios,
                          iconSize: 14,
                          tooltip: 'Forward',
                          onPressed: history.canGoForward
                              ? () => _go(
                                  context,
                                  ref
                                      .read(navigationHistoryProvider.notifier)
                                      .forward(),
                                )
                              : null,
                        ),
                      ],
                      const SizedBox(width: 12),
                      IgnorePointer(
                        child: Text(
                          pageTitle(location),
                          key: const Key('title-bar-title'),
                          style: text.windowTitle,
                        ),
                      ),
                      const Spacer(),
                      if (!minimal) const _SearchField(),
                      SizedBox(width: isMac ? 16 : 12),
                      if (!isMac) ...[
                        _CaptionButton(
                          key: const Key('caption-minimize'),
                          icon: Icons.remove,
                          onPressed: controls.minimize,
                        ),
                        _CaptionButton(
                          key: const Key('caption-maximize'),
                          icon: Icons.crop_square,
                          onPressed: controls.toggleMaximize,
                        ),
                        _CaptionButton(
                          key: const Key('caption-close'),
                          icon: Icons.close,
                          danger: true,
                          onPressed: controls.close,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const EdgeLine.glowInMiddle(axis: Axis.horizontal),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String? target) {
    if (target != null) context.go(target);
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 18,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return IconButton(
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      onPressed: onPressed,
      color: tokens.muted,
      disabledColor: tokens.faint.withValues(alpha: 0.4),
      hoverColor: tokens.glowSoft,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShelfRadius.control),
        ),
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.icon,
    required this.onPressed,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return InkResponse(
      onTap: onPressed,
      hoverColor: danger
          ? tokens.danger.withValues(alpha: 0.85)
          : tokens.glowSoft,
      highlightShape: BoxShape.rectangle,
      containedInkWell: true,
      child: SizedBox(
        width: 46,
        height: 52,
        child: Icon(icon, size: 16, color: tokens.muted),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(filtersProvider).search,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    ref.listen(filtersProvider.select((filters) => filters.search), (_, next) {
      if (_controller.text != next) _controller.text = next;
    });

    return SizedBox(
      width: 340,
      height: 30,
      child: TextField(
        key: const Key('search-field'),
        controller: _controller,
        onChanged: ref.read(filtersProvider.notifier).setSearch,
        focusNode: ref.watch(searchFocusNodeProvider),
        style: text.fieldText,
        decoration: InputDecoration(
          hintText: 'Search your games',
          prefixIcon: Icon(Icons.search, size: 16, color: tokens.faint),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          suffixIcon: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  child: Text(isMac ? '⌘K' : 'Ctrl K', style: text.keyHint),
                ),
              ),
            ),
          ),
          filled: true,
          fillColor: tokens.surface2.withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}
