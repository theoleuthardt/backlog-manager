import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

/// A 38 x 22 switch; on it is filled with the accent and glows.
class ShelfSwitch extends StatelessWidget {
  const ShelfSwitch({
    required this.value,
    required this.onChanged,
    this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Read out by assistive technology.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final animations = !MediaQuery.of(context).disableAnimations;
    final duration = animations
        ? const Duration(milliseconds: 150)
        : Duration.zero;

    return Semantics(
      toggled: value,
      child: ShelfPressable(
        onPressed: onChanged == null ? null : () => onChanged!(!value),
        semanticLabel: label,
        borderRadius: 11,
        builder: (context, state) => SizedBox(
          width: 38,
          height: 22,
          child: DecoratedBox(
            key: const Key('switch-track'),
            decoration: BoxDecoration(
              color: value ? tokens.accent : tokens.surface3,
              borderRadius: BorderRadius.circular(11),
              boxShadow: value ? ShelfGlow.switchOn(tokens) : null,
            ),
            child: AnimatedAlign(
              duration: duration,
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  key: const Key('switch-thumb'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? tokens.onAccent : tokens.foreground,
                  ),
                  child: const SizedBox(width: 18, height: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An 18 px checkbox. [value] null is the mixed state (some rows selected);
/// a tap on an unchecked or mixed box reports `true`.
class ShelfCheckbox extends StatelessWidget {
  const ShelfCheckbox({
    required this.value,
    required this.onChanged,
    this.label,
    super.key,
  });

  final bool? value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final filled = value != false;

    return Semantics(
      checked: value ?? false,
      mixed: value == null,
      child: ShelfPressable(
        onPressed: onChanged == null ? null : () => onChanged!(value != true),
        semanticLabel: label,
        borderRadius: 5,
        builder: (context, state) => DecoratedBox(
          key: const Key('checkbox-box'),
          decoration: BoxDecoration(
            color: filled ? tokens.accent : null,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: filled
                  ? tokens.accent
                  : state.hovered
                  ? tokens.glow
                  : tokens.borderStrong,
              width: 1.5,
            ),
          ),
          child: SizedBox(
            width: 18,
            height: 18,
            child: filled
                ? Icon(
                    value == null ? Icons.remove : Icons.check,
                    size: 14,
                    color: tokens.onAccent,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
