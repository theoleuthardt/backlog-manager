import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

enum ShelfChipKind { neutral, active, accent, info, ok, add }

/// A 24 px pill for tags and filter tokens. [onPressed] makes it clickable,
/// [onRemove] adds a small x on its right.
class ShelfChip extends StatelessWidget {
  const ShelfChip({
    required this.label,
    this.kind = ShelfChipKind.neutral,
    this.onPressed,
    this.onRemove,
    super.key,
  });

  final String label;
  final ShelfChipKind kind;
  final VoidCallback? onPressed;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    Widget chip(ShelfInteraction? state) {
      final hovered = state?.hovered ?? false;
      final foreground = _foreground(tokens, hovered);
      final content = Padding(
        padding: EdgeInsets.only(left: 10, right: onRemove == null ? 10 : 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: text.label.copyWith(color: foreground)),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              ShelfPressable(
                key: const Key('chip-remove'),
                onPressed: onRemove,
                borderRadius: 7,
                semanticLabel: 'Remove $label',
                builder: (context, state) =>
                    Icon(Icons.close, size: 14, color: tokens.faint),
              ),
            ],
          ],
        ),
      );
      final decoration = _decoration(tokens, hovered);
      if (kind == ShelfChipKind.add) {
        return CustomPaint(
          key: const Key('chip-dashed-border'),
          foregroundPainter: _DashedPillPainter(
            hovered ? tokens.glow : tokens.borderStrong,
          ),
          child: DecoratedBox(
            key: const Key('chip-surface'),
            decoration: decoration,
            child: SizedBox(
              height: 24,
              child: Center(widthFactor: 1, child: content),
            ),
          ),
        );
      }
      return DecoratedBox(
        key: const Key('chip-surface'),
        decoration: decoration,
        child: SizedBox(
          height: 24,
          child: Center(widthFactor: 1, child: content),
        ),
      );
    }

    if (onPressed == null) return chip(null);
    return ShelfPressable(
      onPressed: onPressed,
      semanticLabel: onRemove == null ? label : null,
      borderRadius: 12,
      builder: (context, state) => chip(state),
    );
  }

  Color _foreground(ShelfTokens tokens, bool hovered) {
    return switch (kind) {
      ShelfChipKind.neutral => tokens.text2,
      ShelfChipKind.active => tokens.background,
      ShelfChipKind.accent => tokens.accent,
      ShelfChipKind.info => tokens.info,
      ShelfChipKind.ok => tokens.success,
      ShelfChipKind.add => hovered ? tokens.foreground : tokens.muted,
    };
  }

  BoxDecoration _decoration(ShelfTokens tokens, bool hovered) {
    final radius = BorderRadius.circular(999);
    return switch (kind) {
      ShelfChipKind.neutral => BoxDecoration(
        color: tokens.surface2,
        borderRadius: radius,
        border: Border.all(color: hovered ? tokens.glow : tokens.borderSubtle),
      ),
      ShelfChipKind.active => BoxDecoration(
        color: tokens.foreground,
        borderRadius: radius,
      ),
      ShelfChipKind.accent => BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: radius,
      ),
      ShelfChipKind.info => BoxDecoration(
        color: atOpacity(tokens.info, 0.14),
        borderRadius: radius,
      ),
      ShelfChipKind.ok => BoxDecoration(
        color: atOpacity(tokens.success, 0.14),
        borderRadius: radius,
      ),
      ShelfChipKind.add => BoxDecoration(borderRadius: radius),
    };
  }
}

class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ).deflate(0.5),
      );
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter oldDelegate) =>
      oldDelegate.color != color;
}
