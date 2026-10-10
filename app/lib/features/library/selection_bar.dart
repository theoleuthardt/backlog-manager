import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/data/selection_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/domain/library_groups.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/library/library_actions.dart';
import 'package:backlog_manager/features/library/library_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The accent-tinted bar that replaces the toolbar while games are selected:
/// the number selected, select all and clear, the status and category menus
/// for the whole selection, delete, and Done on the right.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({required this.gutter, super.key});

  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final selection = ref.watch(selectionProvider);
    final notifier = ref.read(selectionProvider.notifier);
    final content = ref.watch(libraryContentProvider);
    final visibleIds = [
      for (final group in content?.groups ?? const <LibraryGroup>[])
        for (final entry in group.entries) entry.id,
    ];
    final statuses = ref.watch(
      filterOptionsProvider.select((options) => options.statuses),
    );
    final categories =
        ref.watch(categoriesProvider(null)).value ?? const <Category>[];
    final byEntry = ref.watch(entryCategoriesProvider(null)).value;
    final actions = LibraryActionsScope.of(context);
    final ids = selection.ids.toList()..sort();
    final none = ids.isEmpty;
    final allSelected = ids.length == visibleIds.length;

    bool everySelectedHas(Category category) {
      return ids.every(
        (id) => (byEntry?[id] ?? const []).any((c) => c.id == category.id),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 8),
      child: DecoratedBox(
        key: const Key('selection-bar'),
        decoration: BoxDecoration(
          color: tokens.accentSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${ids.length} selected',
                key: const Key('selected-count'),
                style: style.control.copyWith(color: tokens.foreground),
              ),
              ShelfButton(
                key: const Key('select-all'),
                label: 'Select all ${visibleIds.length}',
                kind: ShelfButtonKind.quiet,
                onPressed: allSelected
                    ? null
                    : () => notifier.selectAll(visibleIds),
              ),
              ShelfButton(
                key: const Key('selection-clear'),
                label: 'Clear',
                kind: ShelfButtonKind.quiet,
                onPressed: none ? null : notifier.clear,
              ),
              ShelfMenuAnchor(
                entries: [
                  for (final status in statuses)
                    ShelfMenuItem(
                      label: status,
                      onSelected: () => actions.setStatusOfMany(ids, status),
                    ),
                ],
                builder: (context, controller) => ShelfButton(
                  key: const Key('selection-set-status'),
                  label: 'Set status',
                  onPressed: none
                      ? null
                      : () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                ),
              ),
              ShelfMenuAnchor(
                entries: [
                  for (final category in categories)
                    ShelfMenuItem(
                      label: category.name,
                      checked: everySelectedHas(category),
                      onSelected: () => actions.setCategoryOfMany(
                        ids,
                        category,
                        assigned: !everySelectedHas(category),
                      ),
                    ),
                ],
                builder: (context, controller) => ShelfButton(
                  key: const Key('selection-categories'),
                  label: 'Categories',
                  onPressed: none || categories.isEmpty
                      ? null
                      : () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                ),
              ),
              ShelfButton(
                key: const Key('selection-delete'),
                label: 'Delete',
                kind: ShelfButtonKind.danger,
                onPressed: none
                    ? null
                    : () => actions.deleteEntries([
                        for (final entry
                            in ref.read(entriesProvider(null)).value ??
                                const <BacklogEntry>[])
                          if (selection.ids.contains(entry.id)) entry,
                      ]),
              ),
              ShelfButton(
                key: const Key('selection-done'),
                label: 'Done',
                kind: ShelfButtonKind.primary,
                onPressed: notifier.end,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
