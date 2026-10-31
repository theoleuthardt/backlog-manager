import 'package:backlog_manager/data/selection_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/shell/gamepad.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bar under the page of a phone or handheld that names what the buttons
/// of the gamepad do ([gamepadHints]); it only shows while the gamepad is in
/// use ([gamepadInUseProvider]).
class GamepadHints extends ConsumerWidget {
  const GamepadHints({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(gamepadInUseProvider)) return const SizedBox.shrink();
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final selecting = ref.watch(selectionProvider.select((s) => s.active));

    return DecoratedBox(
      key: const Key('gamepad-hints'),
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border(top: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final hint in gamepadHints(selecting: selecting))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        child: Text(hint.button, style: style.keyHint),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hint.action,
                      style: style.caption.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
