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

/// A track of mutually exclusive segments; the selected one is raised onto
/// `surface3` with a soft shadow.
class ShelfSegmented<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      key: const Key('segmented-track'),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(ShelfRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final segment in segments)
              _buildSegment(context, tokens, text, segment),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    ShelfTokens tokens,
    ShelfTextStyles text,
    ShelfSegment<T> segment,
  ) {
    final selected = segment.value == value;
    return Semantics(
      key: Key('segment-${segment.value}'),
      selected: selected,
      child: ShelfPressable(
        onPressed: () => onChanged(segment.value),
        semanticLabel: segment.label,
        borderRadius: 6,
        builder: (context, state) => DecoratedBox(
          key: Key('segment-${segment.value}-surface'),
          decoration: BoxDecoration(
            color: selected ? tokens.surface3 : null,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: SizedBox(
            height: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (segment.icon != null) ...[
                    Icon(
                      segment.icon,
                      size: 14,
                      color: selected ? tokens.foreground : tokens.muted,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    segment.label,
                    style: text.control.copyWith(
                      color: selected || state.hovered
                          ? tokens.foreground
                          : tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
