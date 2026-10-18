import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

/// Text tabs; the active one is underlined with 2 px in the accent colour.
/// With [expand] the tabs share the width they are given equally, with the
/// labels centred, instead of sitting at their own width on the left.
class ShelfTabs extends StatelessWidget {
  const ShelfTabs({
    required this.labels,
    required this.index,
    required this.onChanged,
    this.expand = false,
    super.key,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool expand;

  Widget _slot(Widget tab) => expand ? Expanded(child: tab) : tab;

  Widget _fit(Widget column) => expand ? column : IntrinsicWidth(child: column);

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            _slot(
              Semantics(
                key: Key('tab-$i'),
                selected: i == index,
                child: ShelfPressable(
                  onPressed: () => onChanged(i),
                  semanticLabel: labels[i],
                  borderRadius: 4,
                  builder: (context, state) => Padding(
                    padding: EdgeInsets.only(right: expand ? 0 : 20),
                    child: _fit(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              labels[i],
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: text.control.copyWith(
                                color: i == index || state.hovered
                                    ? tokens.foreground
                                    : tokens.muted,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 2,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: i == index ? 1 : 0),
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              builder: (context, factor, child) => Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.diagonal3Values(
                                  factor,
                                  1,
                                  1,
                                ),
                                child: child,
                              ),
                              child: ColoredBox(
                                key: i == index
                                    ? const Key('tab-underline')
                                    : null,
                                color: tokens.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
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
