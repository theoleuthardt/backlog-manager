import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// An error message above a form, in the danger colour on a tint of it.
/// With [actionLabel] it ends in a link, for example one that opens the
/// details of the error.
class ShelfBanner extends StatelessWidget {
  const ShelfBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return Semantics(
      liveRegion: true,
      label: message,
      excludeSemantics: actionLabel == null,
      child: DecoratedBox(
        key: const Key('error-banner'),
        decoration: BoxDecoration(
          color: atOpacity(tokens.danger, 0.12),
          borderRadius: BorderRadius.circular(ShelfRadius.control),
          border: Border.all(color: atOpacity(tokens.danger, 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 16, color: tokens.danger),
              const SizedBox(width: 8),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    message,
                    style: text.caption.copyWith(color: tokens.danger),
                  ),
                ),
              ),
              if (actionLabel case final label?) ...[
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: label,
                  excludeSemantics: true,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: const Key('error-banner-action'),
                      onTap: onAction,
                      child: Text(
                        label,
                        style: text.caption.copyWith(
                          color: tokens.danger,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: tokens.danger,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
