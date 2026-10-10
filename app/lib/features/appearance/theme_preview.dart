import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:flutter/material.dart';

/// A miniature window in the colours of the app: tabs, a group with covers, a
/// primary and a secondary button. The app around it already shows the colours
/// being edited, so this uses the ambient theme.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      key: const Key('theme-preview'),
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderStrong),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: tokens.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    for (final color in [
                      tokens.danger,
                      tokens.accent,
                      tokens.success,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(width: 9, height: 9),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      'Preview',
                      style: style.caption.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Wrap(
                    spacing: 6,
                    children: [
                      ShelfChip(label: 'Library', kind: ShelfChipKind.active),
                      ShelfChip(label: 'Space'),
                      ShelfChip(
                        label: 'In Progress',
                        kind: ShelfChipKind.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Expanded(child: ShelfCover(title: 'Hades')),
                      SizedBox(width: 12),
                      Expanded(child: ShelfCover(title: 'Hollow Knight')),
                      SizedBox(width: 12),
                      Expanded(child: ShelfCover(title: 'Stardew Valley')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ShelfButton(
                        label: 'Primary',
                        kind: ShelfButtonKind.primary,
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      ShelfButton(label: 'Secondary', onPressed: () {}),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
