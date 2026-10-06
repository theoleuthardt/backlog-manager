import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

enum ShelfButtonKind { primary, secondary, quiet, danger }

/// A 32 px button. Primary has the accent gradient and glow, secondary the
/// strong border, quiet only muted text, danger writes in the danger colour.
/// Without [onPressed] it is dimmed to 40% and does nothing.
class ShelfButton extends StatelessWidget {
  const ShelfButton({
    required this.label,
    required this.onPressed,
    this.kind = ShelfButtonKind.secondary,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ShelfButtonKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: ShelfPressable(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, state) {
          final color = _labelColor(tokens, state);
          return DecoratedBox(
            key: const Key('button-surface'),
            decoration: _decoration(tokens, state),
            child: SizedBox(
              height: ShelfHeight.control,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                    ],
                    Text(label, style: text.control.copyWith(color: color)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _labelColor(ShelfTokens tokens, ShelfInteraction state) {
    return switch (kind) {
      ShelfButtonKind.primary => tokens.onAccent,
      ShelfButtonKind.secondary => tokens.foreground,
      ShelfButtonKind.quiet => state.hovered ? tokens.foreground : tokens.muted,
      ShelfButtonKind.danger => tokens.danger,
    };
  }

  BoxDecoration _decoration(ShelfTokens tokens, ShelfInteraction state) {
    final radius = BorderRadius.circular(ShelfRadius.control);
    switch (kind) {
      case ShelfButtonKind.primary:
        final base = ShelfGlow.primaryButton(
          tokens,
          radius: ShelfRadius.control,
        );
        if (!state.hovered) return base;
        return base.copyWith(
          boxShadow: [
            BoxShadow(color: atOpacity(tokens.accent, 0.55), blurRadius: 28),
          ],
        );
      case ShelfButtonKind.secondary:
        return BoxDecoration(
          color: state.pressed
              ? tokens.surface3
              : state.hovered
              ? tokens.surface2
              : null,
          borderRadius: radius,
          border: Border.all(
            color: state.hovered ? tokens.glow : tokens.borderStrong,
          ),
          boxShadow: state.hovered
              ? [BoxShadow(color: tokens.glowSoft, blurRadius: 12)]
              : null,
        );
      case ShelfButtonKind.quiet:
        return BoxDecoration(
          color: state.hovered ? tokens.glowSoft : null,
          borderRadius: radius,
        );
      case ShelfButtonKind.danger:
        return BoxDecoration(
          color: state.hovered ? atOpacity(tokens.danger, 0.12) : null,
          borderRadius: radius,
        );
    }
  }
}

/// A 32 px square button with only an icon; [tooltip] is also its label for
/// assistive technology.
class ShelfIconButton extends StatelessWidget {
  const ShelfIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Tooltip(
        message: tooltip,
        child: ShelfPressable(
          onPressed: onPressed,
          semanticLabel: tooltip,
          builder: (context, state) => DecoratedBox(
            key: const Key('button-surface'),
            decoration: BoxDecoration(
              color: state.hovered ? tokens.glowSoft : null,
              borderRadius: BorderRadius.circular(ShelfRadius.control),
            ),
            child: SizedBox(
              width: ShelfHeight.control,
              height: ShelfHeight.control,
              child: Icon(
                icon,
                size: 18,
                color: state.hovered ? tokens.foreground : tokens.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
