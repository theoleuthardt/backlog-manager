import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A bar that fills the share [value] (0 to 1) of its track with the glowing
/// accent gradient.
class ShelfProgressBar extends StatelessWidget {
  const ShelfProgressBar({required this.value, this.height = 6, super.key});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final share = value.clamp(0, 1).toDouble();
    final radius = BorderRadius.circular(height / 2);

    return SizedBox(
      height: height,
      child: DecoratedBox(
        key: const Key('progress-track'),
        decoration: BoxDecoration(color: tokens.surface3, borderRadius: radius),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.centerLeft,
            child: share == 0
                ? null
                : DecoratedBox(
                    key: const Key('progress-fill'),
                    decoration: ShelfGlow.progress(tokens)
                        .copyWith(borderRadius: radius),
                    child: SizedBox(
                      width: constraints.maxWidth * share,
                      height: height,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Ten segments for how much a game interests the player; [value] of them are
/// filled. Tapping segment n sets the value to n, tapping the current value
/// clears it. Without [onChanged] it only shows the value.
class InterestSegments extends StatelessWidget {
  const InterestSegments({required this.value, this.onChanged, super.key});

  static const count = 10;

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    return _Adjustable(
      label: 'Interest: $value of $count',
      value: value,
      max: count,
      onChanged: onChanged,
      child: Row(
        children: [
          for (var n = 1; n <= count; n++) ...[
            if (n > 1) const SizedBox(width: 3),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(n == value ? 0 : n),
                child: SizedBox(
                  height: 18,
                  child: Center(
                    child: DecoratedBox(
                      key: Key('interest-$n'),
                      decoration: BoxDecoration(
                        color: n <= value ? tokens.accent : tokens.surface3,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const SizedBox(height: 6, width: double.infinity),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A review of up to ten stars; [value] of them are filled. Tapping star n
/// sets the value to n, tapping the current value clears it.
class StarRating extends StatelessWidget {
  const StarRating({
    required this.value,
    this.onChanged,
    this.max = 10,
    super.key,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final int max;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    return _Adjustable(
      label: 'Review: $value of $max stars',
      value: value,
      max: max,
      onChanged: onChanged,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var n = 1; n <= max; n++)
            GestureDetector(
              key: Key('star-$n'),
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(n == value ? 0 : n),
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  n <= value ? Icons.star : Icons.star_border,
                  size: 18,
                  color: n <= value ? tokens.accent : tokens.faint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One focusable control for a row of tappable steps: the arrow keys and the
/// accessibility increase and decrease actions move [value] by one between 0
/// and [max], the single steps inside [child] stay out of the semantics tree.
class _Adjustable extends StatelessWidget {
  const _Adjustable({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.child,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int>? onChanged;
  final Widget child;

  void _step(int delta) {
    final next = (value + delta).clamp(0, max);
    if (next != value) onChanged!(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _step(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (onChanged == null) return Semantics(label: label, child: child);
    return Semantics(
      label: label,
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      child: Focus(
        onKeyEvent: _onKey,
        child: ExcludeSemantics(child: child),
      ),
    );
  }
}
