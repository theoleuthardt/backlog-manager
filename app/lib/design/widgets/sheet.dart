import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:flutter/material.dart';

enum ShelfSheetWidth {
  compact(520),
  standard(640),
  wide(680);

  const ShelfSheetWidth(this.value);

  final double value;
}

/// A sheet: a head with the title and a close button, a scrolling body and an
/// optional [footer] on `surface2`.
class ShelfSheet extends StatelessWidget {
  const ShelfSheet({
    required this.title,
    required this.child,
    this.description,
    this.footer,
    this.width = ShelfSheetWidth.standard,
    this.onClose,
    super.key,
  });

  final String title;
  final String? description;
  final Widget child;
  final Widget? footer;
  final ShelfSheetWidth width;

  /// Called by the close button; by default the sheet pops its route.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return SizedBox(
      width: width.value,
      child: DecoratedBox(
        key: const Key('sheet-surface'),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(ShelfRadius.dialog),
          border: Border.all(color: tokens.borderStrong),
          boxShadow: [
            BoxShadow(
              color: tokens.shadow,
              blurRadius: 80,
              offset: const Offset(0, 24),
            ),
            BoxShadow(color: tokens.glowSoft, blurRadius: 60),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ShelfRadius.dialog - 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.section),
                          if (description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                description!,
                                style: text.caption.copyWith(
                                  color: tokens.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ShelfIconButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onPressed:
                          onClose ?? () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: child,
                ),
              ),
              if (footer != null)
                ColoredBox(
                  key: const Key('sheet-footer'),
                  color: tokens.surface2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: footer,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The footer of a sheet: Cancel with its Esc hint on the left, the primary
/// action on the right.
class ShelfSheetFooter extends StatelessWidget {
  const ShelfSheetFooter({
    required this.onCancel,
    required this.primary,
    this.cancelLabel = 'Cancel',
    super.key,
  });

  final VoidCallback? onCancel;
  final Widget primary;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return Row(
      children: [
        ShelfButton(
          label: cancelLabel,
          kind: ShelfButtonKind.quiet,
          onPressed: onCancel,
        ),
        const SizedBox(width: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Text(
              'Esc',
              style: text.label.copyWith(fontSize: 11, color: tokens.faint),
            ),
          ),
        ),
        const Spacer(),
        primary,
      ],
    );
  }
}

/// Shows the sheet [builder] builds, dropping 8 px from just below the title
/// bar over a dimmed window. Esc and a click outside close it unless it is not
/// [dismissible] (a running import, for example).
Future<T?> showShelfSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: Theme.of(context).extension<ShelfTokens>()!.scrim,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondary) => Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: builder(context),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = !MediaQuery.of(context).disableAnimations;
      return FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, slide ? -8 * (1 - curved.value) : 0),
            child: child,
          ),
          child: child,
        ),
      );
    },
  );
}
