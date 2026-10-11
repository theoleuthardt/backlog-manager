import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

class ShelfSegment<T> {
  const ShelfSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A track of mutually exclusive segments; the selected one is marked by a
/// raised thumb on `surface3` that slides to the segment that is chosen.
class ShelfSegmented<T> extends StatefulWidget {
  const ShelfSegmented({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<ShelfSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<ShelfSegmented<T>> createState() => _ShelfSegmentedState<T>();
}

class _ShelfSegmentedState<T> extends State<ShelfSegmented<T>> {
  final _track = GlobalKey();
  late List<GlobalKey> _keys;
  Rect? _thumb;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.segments.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(ShelfSegmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments.length != widget.segments.length) {
      _keys = List.generate(widget.segments.length, (_) => GlobalKey());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final index = widget.segments.indexWhere((s) => s.value == widget.value);
    final track = _track.currentContext?.findRenderObject();
    final segment = index == -1
        ? null
        : _keys[index].currentContext?.findRenderObject();
    if (track is! RenderBox || segment is! RenderBox) return;
    final origin = segment.localToGlobal(Offset.zero, ancestor: track);
    final next = origin & segment.size;
    if (next != _thumb) setState(() => _thumb = next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final thumb = _thumb;

    return DecoratedBox(
      key: const Key('segmented-track'),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(ShelfRadius.control),
      ),
      child: Stack(
        key: _track,
        children: [
          if (thumb != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: thumb.left,
              top: thumb.top,
              width: thumb.width,
              height: thumb.height,
              child: DecoratedBox(
                key: const Key('segmented-thumb'),
                decoration: BoxDecoration(
                  color: tokens.surface3,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.shadow,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, segment) in widget.segments.indexed)
                  _buildSegment(_keys[index], tokens, text, segment),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    GlobalKey key,
    ShelfTokens tokens,
    ShelfTextStyles text,
    ShelfSegment<T> segment,
  ) {
    final selected = segment.value == widget.value;
    return Semantics(
      key: Key('segment-${segment.value}'),
      selected: selected,
      child: ShelfPressable(
        onPressed: () => widget.onChanged(segment.value),
        semanticLabel: segment.label,
        borderRadius: 8,
        builder: (context, state) => SizedBox(
          key: key,
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segment.icon != null) ...[
                  Icon(
                    segment.icon,
                    size: 16,
                    color: selected ? tokens.foreground : tokens.muted,
                  ),
                  const SizedBox(width: 6),
                ],
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: text.control.copyWith(
                    color: selected || state.hovered
                        ? tokens.foreground
                        : tokens.muted,
                  ),
                  child: Text(segment.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
