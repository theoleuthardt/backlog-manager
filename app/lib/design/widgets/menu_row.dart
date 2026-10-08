import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

/// One 32 px row of a popover list: an optional [leading] widget, the label
/// and an optional [trailing] widget, lit on hover.
class ShelfMenuRow extends StatelessWidget {
  const ShelfMenuRow({
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.labelStyle,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? leading;
  final Widget? trailing;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return ShelfPressable(
      borderRadius: 6,
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, state) => DecoratedBox(
        decoration: BoxDecoration(
          color: state.hovered ? tokens.glowSoft : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 4)],
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle ?? style.control,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
