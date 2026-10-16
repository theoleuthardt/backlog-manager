import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/shell/palette_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the list of every keyboard shortcut of the app, centred over the
/// window like the command palette.
Future<void> showShortcutsSheet(BuildContext context) {
  return showShelfSheet<void>(context, builder: (_) => const _ShortcutsSheet());
}

class _ShortcutsSheet extends ConsumerWidget {
  const _ShortcutsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final modifier = isMac ? '⌘' : 'Ctrl+';

    final rows = <(String, String)>[
      ('Open the command palette', '${modifier}K'),
      for (final action in ref.watch(paletteRegistryProvider))
        if (action.shortcut != null)
          (action.label, action.shortcut!.display(isMac: isMac)),
      ('Focus the search field', '${modifier}S'),
      ('Close the palette, a sheet or the details', 'Esc'),
    ];

    return ShelfSheet(
      title: 'Shortcuts',
      description: 'Everything you can do from the keyboard.',
      child: Column(
        key: const Key('shortcuts-list'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, keys) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: style.body.copyWith(color: tokens.foreground),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(keys, style: style.keyHint),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
