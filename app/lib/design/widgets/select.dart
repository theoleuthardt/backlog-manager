import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

class ShelfOption<T> {
  const ShelfOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// A labelled drop-down: a 34 px trigger on `surface2` that opens the options
/// as a menu with the current one checked.
class ShelfSelect<T> extends StatelessWidget {
  const ShelfSelect({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hintText,
    super.key,
  });

  final String label;
  final List<ShelfOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final chosen = options.where((option) => option.value == value).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.label.copyWith(color: tokens.muted)),
        const SizedBox(height: 6),
        ShelfMenuAnchor(
          entries: [
            for (final option in options)
              ShelfMenuItem(
                label: option.label,
                checked: option.value == value,
                onSelected: () => onChanged(option.value),
              ),
          ],
          builder: (context, controller) => ShelfPressable(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            semanticLabel: label,
            builder: (context, state) => SizedBox(
              key: const Key('select-trigger'),
              height: ShelfHeight.input,
              child: DecoratedBox(
                key: const Key('select-surface'),
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(ShelfRadius.control),
                  border: Border.all(
                    color: state.hovered ? tokens.glow : tokens.borderSubtle,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chosen?.label ?? hintText ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: text.fieldText.copyWith(
                            color: chosen == null
                                ? tokens.faint
                                : tokens.foreground,
                          ),
                        ),
                      ),
                      Icon(Icons.expand_more, size: 18, color: tokens.faint),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
