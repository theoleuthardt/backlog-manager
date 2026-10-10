import 'dart:async';

import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/drag_providers.dart';
import 'package:backlog_manager/domain/drag_drop.dart';
import 'package:backlog_manager/domain/library_groups.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/library/library_actions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _dragDistance = 8.0;
const _touchHold = Duration(milliseconds: 250);
const _scrollTick = Duration(milliseconds: 16);

class _DistancePointerState extends MultiDragPointerState {
  _DistancePointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
  );

  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > _dragDistance) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class _HoldPointerState extends MultiDragPointerState {
  _HoldPointerState(super.initialPosition, super.kind, super.gestureSettings) {
    _timer = Timer(_touchHold, _held);
  }

  Timer? _timer;
  GestureMultiDragStartCallback? _starter;

  void _held() {
    _timer = null;
    final starter = _starter;
    if (starter == null) {
      resolve(GestureDisposition.accepted);
    } else {
      starter(initialPosition);
      _starter = null;
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    if (_timer == null) {
      starter(initialPosition);
    } else {
      _starter = starter;
    }
  }

  @override
  void checkForResolutionAfterMove() {
    if (_timer == null) return;
    if (pendingDelta!.distance > _dragDistance) {
      _timer?.cancel();
      _timer = null;
      resolve(GestureDisposition.rejected);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Recognizes the drag of a game: a mouse or stylus starts it after moving
/// 8 px, a finger after a 250 ms hold, so a click still opens the game and
/// touch scrolling keeps working.
class _EntryDragRecognizer extends MultiDragGestureRecognizer {
  _EntryDragRecognizer({super.allowedButtonsFilter}) : super(debugOwner: null);

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return event.kind == PointerDeviceKind.touch
        ? _HoldPointerState(event.position, event.kind, gestureSettings)
        : _DistancePointerState(event.position, event.kind, gestureSettings);
  }

  @override
  String get debugDescription => 'entry drag';
}

class _EntryDraggable extends Draggable<int> {
  const _EntryDraggable({
    required super.data,
    required super.feedback,
    required super.child,
    super.childWhenDragging,
    super.dragAnchorStrategy,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDragEnd,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    return _EntryDragRecognizer(allowedButtonsFilter: allowedButtonsFilter)
      ..onStart = onStart;
  }
}

/// Makes [child], the tile or row of [entry], draggable onto the groups of
/// the library. The drag itself is run by the [LibraryDrag] of the page.
class EntryDragSource extends StatelessWidget {
  const EntryDragSource({
    required this.entry,
    required this.drag,
    required this.child,
    super.key,
  });

  final BacklogEntry entry;
  final LibraryDrag drag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return _EntryDraggable(
          data: entry.id,
          dragAnchorStrategy: (draggable, context, position) =>
              Offset(width / 2, 24),
          feedback: IgnorePointer(
            key: const Key('drag-preview'),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: width,
                child: Opacity(
                  opacity: 0.92,
                  child: Transform.scale(scale: 1.04, child: child),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: child),
          onDragStarted: () => drag.start(entry.id),
          onDragUpdate: (details) => drag.update(details.globalPosition),
          onDragEnd: (_) => drag.end(entry),
          child: child,
        );
      },
    );
  }
}

/// Hands the [LibraryDrag] of the library page down to its games.
class LibraryDragScope extends InheritedWidget {
  const LibraryDragScope({required this.drag, required super.child, super.key});

  final LibraryDrag drag;

  static LibraryDrag? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LibraryDragScope>()?.drag;
  }

  @override
  bool updateShouldNotify(LibraryDragScope oldWidget) => false;
}

/// Runs the drag of a game over the library: finds the group under the
/// pointer from the headers on screen, scrolls while the pointer is near the
/// top or bottom edge and, on the drop, moves the game to the status or the
/// category of the group.
class LibraryDrag {
  LibraryDrag({
    required this.ref,
    required this.context,
    required this.groups,
    required this.headerKeys,
    required this.viewportKey,
    required this.scroll,
  });

  final WidgetRef ref;
  final BuildContext context;
  final List<LibraryGroup> Function() groups;
  final Map<String, GlobalKey> headerKeys;
  final GlobalKey viewportKey;
  final ScrollController scroll;

  Timer? _timer;
  Offset? _pointer;

  Rect? get _viewport {
    final box = viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void start(int entryId) {
    ref.read(dragProvider.notifier).begin(entryId);
    _timer?.cancel();
    _timer = Timer.periodic(_scrollTick, (_) => _scrollTowardsEdge());
  }

  void _scrollTowardsEdge() {
    final pointer = _pointer;
    final viewport = _viewport;
    if (pointer == null || viewport == null || !scroll.hasClients) return;
    final speed = edgeScrollVelocity(
      pointer.dy,
      top: viewport.top,
      bottom: viewport.bottom,
    );
    if (speed == 0) return;
    final position = scroll.position;
    final target = (position.pixels + speed).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    scroll.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pointer != null) update(_pointer!);
    });
  }

  void update(Offset pointer) {
    _pointer = pointer;
    ref.read(dragProvider.notifier).over(_groupAt(pointer)?.key);
  }

  LibraryGroup? _groupAt(Offset pointer) {
    final viewport = _viewport;
    if (viewport == null || !viewport.contains(pointer)) return null;
    final list = groups();
    final tops = <int, double>{};
    for (var index = 0; index < list.length; index++) {
      final box = headerKeys[list[index].key]?.currentContext
          ?.findRenderObject();
      if (box is RenderBox && box.attached) {
        tops[index] = box.localToGlobal(Offset.zero).dy;
      }
    }
    final index = groupIndexAt(pointer.dy, tops);
    final group = index == null ? null : list[index];
    return group != null && group.droppable ? group : null;
  }

  Future<void> end(BacklogEntry entry) async {
    _timer?.cancel();
    _timer = null;
    final key = ref.read(dragProvider).overGroupKey;
    _pointer = null;
    ref.read(dragProvider.notifier).end();
    if (key == null) return;
    final group = groups().where((group) => group.key == key).firstOrNull;
    if (group == null || !context.mounted) return;
    final actions = LibraryActions(context, ref);
    final status = group.status;
    if (status != null) {
      if (status != entry.status) await actions.moveEntry(entry, status);
      return;
    }
    final categories =
        ref.read(categoriesProvider(null)).value ?? const <Category>[];
    final target = categories
        .where((category) => category.name == group.label)
        .firstOrNull;
    if (target != null) await actions.moveToCategory(entry, target);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
