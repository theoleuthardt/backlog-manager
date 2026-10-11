import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

enum ShelfButtonKind { primary, secondary, quiet, danger }

/// A 38 px button that eases between its resting, hover and pressed look. Primary has the accent gradient and glow, secondary the
/// strong border, quiet only muted text, danger writes in the danger colour.
/// Without [onPressed] it is dimmed to 40% and does nothing.
class ShelfButton extends StatelessWidget {
  const ShelfButton({
    required this.label,
    required this.onPressed,
    this.kind = ShelfButtonKind.secondary,
    this.icon,
    this.busy = false,
    this.expanded = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ShelfButtonKind kind;

  /// Stretches the button to the width it is given and makes it taller, for
  /// the one main action of a form.
  final bool expanded;
  final IconData? icon;

  /// Shows a spinner before the label and ignores taps; the button keeps its
  /// full colour, unlike a disabled one.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return Opacity(
      opacity: onPressed == null && !busy ? 0.4 : 1,
      child: ShelfPressable(
        onPressed: busy ? _ignore : onPressed,
        pressedScale: 0.97,
        semanticLabel: label,
        builder: (context, state) {
          final color = _labelColor(tokens, state);
          return _EasedSurface(
            decoration: _decoration(tokens, state),
            child: SizedBox(
              height: expanded ? ShelfHeight.input : ShelfHeight.control,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (icon != null) ...[
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.control.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static void _ignore() {}

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

/// A square button as high as [ShelfHeight.control] with only an icon; [tooltip] is also its label for
/// assistive technology.
class ShelfIconButton extends StatelessWidget {
  const ShelfIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
    super.key,
  });

  final IconData icon;

  /// A small second icon at the bottom right of [icon], such as the bolt of
  /// a sync.
  final IconData? badge;
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
          pressedScale: 0.92,
          builder: (context, state) => _EasedSurface(
            decoration: BoxDecoration(
              color: state.hovered ? tokens.glowSoft : null,
              borderRadius: BorderRadius.circular(ShelfRadius.control),
            ),
            child: SizedBox(
              width: ShelfHeight.control,
              height: ShelfHeight.control,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: state.hovered ? tokens.foreground : tokens.muted,
                  ),
                  if (badge != null)
                    Positioned(
                      right: 6,
                      bottom: 5,
                      child: Icon(badge, size: 13, color: tokens.accent),
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

/// The surface of a button: a [DecoratedBox] that eases between its looks
/// (resting, hovered, pressed) instead of switching. It does not add the
/// border to the size like an animated container would.
class _EasedSurface extends StatelessWidget {
  const _EasedSurface({required this.decoration, required this.child});

  final BoxDecoration decoration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Decoration>(
      tween: DecorationTween(end: decoration),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      builder: (context, value, child) => DecoratedBox(
        key: const Key('button-surface'),
        decoration: value,
        child: child,
      ),
      child: child,
    );
  }
}
