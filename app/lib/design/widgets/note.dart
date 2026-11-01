import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:flutter/material.dart';

/// A quiet explanation set apart from the controls it belongs to: an info
/// icon and the text on a soft panel with a thin border. Used instead of
/// loose lines of muted text between groups.
class ShelfNote extends StatefulWidget {
  const ShelfNote({
    this.text,
    this.child,
    this.icon = Icons.info_outline,
    this.closable = false,
    super.key,
  }) : assert((text == null) != (child == null), 'Give either text or a child');

  final String? text;

  /// Replaces [text] when the note holds rich content such as links.
  final Widget? child;
  final IconData icon;

  /// Whether a button closes the note until the page is opened again, for a
  /// hint that takes room from a list on a small screen.
  final bool closable;

  @override
  State<ShelfNote> createState() => _ShelfNoteState();
}

class _ShelfNoteState extends State<ShelfNote> {
  bool _closed = false;

  @override
  Widget build(BuildContext context) {
    if (_closed) return const SizedBox.shrink();
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(ShelfRadius.card),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(widget.icon, size: 18, color: tokens.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  widget.child ??
                  Text(
                    widget.text!,
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
            ),
            if (widget.closable)
              ShelfIconButton(
                icon: Icons.close,
                tooltip: 'Close',
                onPressed: () => setState(() => _closed = true),
              ),
          ],
        ),
      ),
    );
  }
}
