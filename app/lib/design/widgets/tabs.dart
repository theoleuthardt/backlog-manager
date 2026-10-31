import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

/// Text tabs; the active one is underlined with 2 px in the accent colour.
/// With [expand] the tabs share the width they are given equally, with the
/// labels centred, instead of sitting at their own width on the left; on a
/// touch screen where the labels do not fit that way (a phone), the tabs keep
/// their own width and scroll sideways, so no label is cut.
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

  @override
  Widget build(BuildContext context) {
    if (!expand) return _tabs(context, share: false);
    if (!ShelfFormFactor.isTouch(context)) return _tabs(context, share: true);
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var widest = 0.0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: text.control),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        if (widest + _inset <= constraints.maxWidth / labels.length) {
          return _tabs(context, share: true);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _tabs(context, share: false),
        );
      },
    );
  }

  Widget _tabs(BuildContext context, {required bool share}) {
    Widget slot(Widget tab) => share ? Expanded(child: tab) : tab;
    Widget fit(Widget column) => share ? column : IntrinsicWidth(child: column);
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Row(
        mainAxisSize: share ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            slot(
              Semantics(
                key: Key('tab-$i'),
                selected: i == index,
                child: ShelfPressable(
                  onPressed: () => onChanged(i),
                  semanticLabel: labels[i],
                  borderRadius: 4,
                  builder: (context, state) => Padding(
                    padding: EdgeInsets.only(right: share ? 0 : _gap),
                    child: fit(
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

/// The space after a tab that sits at its own width.
const _gap = 20.0;

/// The room a shared tab keeps around its label.
const _inset = 8.0;
