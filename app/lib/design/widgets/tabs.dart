import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

/// Text tabs; the active one is underlined with 2 px in the accent colour.
class ShelfTabs extends StatelessWidget {
  const ShelfTabs({
    required this.labels,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            Semantics(
              key: Key('tab-$i'),
              selected: i == index,
              child: ShelfPressable(
                onPressed: () => onChanged(i),
                semanticLabel: labels[i],
                borderRadius: 4,
                builder: (context, state) => Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            labels[i],
                            style: text.control.copyWith(
                              color: i == index || state.hovered
                                  ? tokens.foreground
                                  : tokens.muted,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 2,
                          child: i == index
                              ? ColoredBox(
                                  key: const Key('tab-underline'),
                                  color: tokens.accent,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
