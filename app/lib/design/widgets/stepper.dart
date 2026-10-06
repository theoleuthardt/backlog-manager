import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// A vertical list of numbered steps: done steps get a success circle with a
/// check, the [current] one an accent circle and the upcoming ones a faint
/// outline.
class ShelfStepper extends StatelessWidget {
  const ShelfStepper({required this.steps, required this.current, super.key});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          SizedBox(
            key: Key('step-$i'),
            height: 36,
            child: Row(
              children: [
                DecoratedBox(
                  key: Key('step-$i-circle'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < current
                        ? tokens.success
                        : i == current
                        ? tokens.accent
                        : null,
                    border: i > current
                        ? Border.all(color: tokens.faint)
                        : null,
                  ),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Center(
                      child: i < current
                          ? Icon(
                              Icons.check,
                              size: 14,
                              color: tokens.background,
                            )
                          : Text(
                              '${i + 1}',
                              style: text.label.copyWith(
                                color: i == current
                                    ? tokens.onAccent
                                    : tokens.faint,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps[i],
                    overflow: TextOverflow.ellipsis,
                    style: text.control.copyWith(
                      color: i <= current ? tokens.foreground : tokens.faint,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
