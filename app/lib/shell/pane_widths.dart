import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which side pane of the window a width belongs to.
enum Pane {
  sidebar(232, 200, 420),
  inspector(380, 320, 640);

  const Pane(this.defaultWidth, this.min, this.max);

  final double defaultWidth;
  final double min;
  final double max;

  double clamp(double width) => width.clamp(min, max);
}

const _storageKey = 'blm-pane-widths';

/// The widths the user dragged the side panes to, kept on the device. A store
/// that cannot be read or written is ignored.
abstract interface class PaneWidthStore {
  Future<Map<Pane, double>> read();

  Future<void> write(Map<Pane, double> widths);
}

class PreferencesPaneWidthStore implements PaneWidthStore {
  const PreferencesPaneWidthStore();

  @override
  Future<Map<Pane, double>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString(_storageKey) ?? '{}');
      if (decoded is! Map) return const {};
      return {
        for (final pane in Pane.values)
          if (decoded[pane.name] case final num width)
            pane: pane.clamp(width.toDouble()),
      };
    } on Object {
      return const {};
    }
  }

  @override
  Future<void> write(Map<Pane, double> widths) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({for (final e in widths.entries) e.key.name: e.value}),
      );
    } on Object {
      return;
    }
  }
}

final paneWidthStoreProvider = Provider<PaneWidthStore>(
  (ref) => const PreferencesPaneWidthStore(),
);

class PaneWidthsNotifier extends Notifier<Map<Pane, double>> {
  @override
  Map<Pane, double> build() {
    unawaited(_load(ref.read(paneWidthStoreProvider)));
    return const {};
  }

  Future<void> _load(PaneWidthStore store) async {
    final stored = await store.read();
    if (ref.mounted && state.isEmpty && stored.isNotEmpty) state = stored;
  }

  double widthOf(Pane pane) => state[pane] ?? pane.defaultWidth;

  /// Moves the edge of [pane] by [delta]; the width stays within the limits
  /// of the pane.
  void resize(Pane pane, double delta) {
    state = {...state, pane: pane.clamp(widthOf(pane) + delta)};
  }

  /// Keeps the widths after a drag.
  void commit() => unawaited(ref.read(paneWidthStoreProvider).write(state));

  void reset(Pane pane) {
    state = {...state}..remove(pane);
    commit();
  }
}

final paneWidthsProvider =
    NotifierProvider<PaneWidthsNotifier, Map<Pane, double>>(
      PaneWidthsNotifier.new,
    );

/// The width of one pane, from the dragged value or its default.
final paneWidthProvider = Provider.family<double, Pane>(
  (ref, pane) => ref.watch(paneWidthsProvider)[pane] ?? pane.defaultWidth,
);

/// The thin strip between two panes that is dragged to resize one of them. A
/// double click restores the default width. [growsToRight] says whether a
/// drag to the right makes the pane larger (the sidebar) or smaller (the
/// inspector).
class PaneResizeHandle extends ConsumerStatefulWidget {
  const PaneResizeHandle({
    required this.pane,
    required this.growsToRight,
    super.key,
  });

  final Pane pane;
  final bool growsToRight;

  @override
  ConsumerState<PaneResizeHandle> createState() => _PaneResizeHandleState();
}

class _PaneResizeHandleState extends ConsumerState<PaneResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final active = _hovered || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        key: Key('resize-${widget.pane.name}'),
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (details) => ref
            .read(paneWidthsProvider.notifier)
            .resize(
              widget.pane,
              widget.growsToRight ? details.delta.dx : -details.delta.dx,
            ),
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          ref.read(paneWidthsProvider.notifier).commit();
        },
        onDoubleTap: () =>
            ref.read(paneWidthsProvider.notifier).reset(widget.pane),
        child: SizedBox(
          width: 8,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 3 : 0,
              color: accent.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
