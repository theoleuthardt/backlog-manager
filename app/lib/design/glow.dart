import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// The glowing accents of the design, built from the tokens.
abstract final class ShelfGlow {
  /// A primary button: a diagonal accent gradient with a glow.
  static BoxDecoration primaryButton(
    ShelfTokens tokens, {
    required double radius,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tokens.accentA, tokens.accentB],
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [BoxShadow(color: tokens.accentGlow, blurRadius: 22)],
    );
  }

  /// A progress bar: an accent gradient from left to right with a small glow.
  static BoxDecoration progress(ShelfTokens tokens) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [tokens.accentA, tokens.accentB],
      ),
      boxShadow: [BoxShadow(color: tokens.accentGlow, blurRadius: 10)],
    );
  }

  /// The shadow of a cover, in the glow colour.
  static List<BoxShadow> coverShadow(ShelfTokens tokens) {
    return [
      BoxShadow(
        color: atOpacity(tokens.glow, 0.45),
        offset: const Offset(0, 14),
        blurRadius: 34,
        spreadRadius: -14,
      ),
    ];
  }

  /// The outline of a selected cover: a 3 px accent border with a glow.
  static BoxDecoration selectedRing(
    ShelfTokens tokens, {
    required double radius,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: tokens.accent, width: 3),
      boxShadow: [BoxShadow(color: tokens.accentGlow, blurRadius: 28)],
    );
  }

  /// The glow of a switch that is on.
  static List<BoxShadow> switchOn(ShelfTokens tokens) {
    return [BoxShadow(color: tokens.accentGlow, blurRadius: 12)];
  }
}

/// A one pixel line that fades between the glow and the border, as on the
/// edges of the title bar, the toolbar, the sidebar and the inspector.
class EdgeLine extends StatelessWidget {
  /// The line glows in its middle and fades to the border at both ends.
  const EdgeLine.glowInMiddle({required this.axis, super.key}) : _middle = true;

  /// The line starts with the glow and fades to the border.
  const EdgeLine.fadeFromGlow({required this.axis, super.key})
    : _middle = false;

  final Axis axis;
  final bool _middle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final horizontal = axis == Axis.horizontal;
    return SizedBox(
      height: horizontal ? 1 : null,
      width: horizontal ? null : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
            end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
            colors: _middle
                ? [tokens.borderSubtle, tokens.glow, tokens.borderSubtle]
                : [tokens.glow, tokens.borderSubtle],
          ),
        ),
      ),
    );
  }
}
