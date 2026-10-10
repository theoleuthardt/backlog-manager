import 'dart:async';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/domain/csv_import.dart';
import 'package:backlog_manager/features/add_game/cover_picker_sheet.dart';
import 'package:backlog_manager/features/add_game/wrong_game_sheet.dart';
import 'package:backlog_manager/features/creation/field_diff_list.dart';
import 'package:backlog_manager/features/import_csv/csv_import_controller.dart';
import 'package:backlog_manager/features/import_csv/csv_row_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The rows of the preview as a list that only builds what is on screen, so a
/// file with a thousand games stays fast.
class CsvPreviewTable extends ConsumerWidget {
  const CsvPreviewTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final order = ref.watch(csvImportProvider.select((state) => state.order));
    final indexes = order ?? const <int>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Preview', style: style.section),
        const SizedBox(height: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(ShelfRadius.card),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: indexes.isEmpty
                ? Center(
                    child: Text(
                      'No rows left to import.',
                      key: const Key('import-no-rows'),
                      style: style.body.copyWith(color: tokens.muted),
                    ),
                  )
                : ListView.builder(
                    key: const Key('import-rows'),
                    itemCount: indexes.length,
                    itemBuilder: (context, position) => CsvRowTile(
                      key: ValueKey(indexes[position]),
                      rowIndex: indexes[position],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// One row of the preview: cover, title and meta line, the chip with the
/// result and the button that fixes it. Only this row rebuilds when it changes.
class CsvRowTile extends ConsumerStatefulWidget {
  const CsvRowTile({required this.rowIndex, super.key});

  final int rowIndex;

  @override
  ConsumerState<CsvRowTile> createState() => _CsvRowTileState();
}

class _CsvRowTileState extends ConsumerState<CsvRowTile> {
  bool _duplicatesOpen = false;

  Future<void> _action(CsvPreviewRow row, RowAction action) async {
    final controller = ref.read(csvImportProvider.notifier);
    switch (action) {
      case RowAction.wrongGame:
        final result = await showWrongGameSheet(
          context,
          initialQuery: row.title,
        );
        if (result != null && mounted) {
          controller.chooseGame(row.rowIndex, result);
        }
      case RowAction.cover:
        final url = await showCoverPicker(context, initialQuery: row.title);
        if (url == null || !mounted) return;
        final current = ref.read(csvRowProvider(row.rowIndex));
        if (current != null) {
          controller.updateRow(current.copyWith(imageLink: url));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = ref.watch(csvRowProvider(widget.rowIndex));
    if (row == null) return const SizedBox.shrink();
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final serverUrl = ref.watch(serverUrlProvider).value;
    final verdict = rowVerdict(row);
    final image = row.imageLink == null || row.imageLink!.isEmpty
        ? null
        : entryImage(serverUrl, row.imageLink!);
    final info = _info(row);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GestureDetector(
                  key: Key('import-cover-${row.rowIndex}'),
                  onTap: () => unawaited(_action(row, RowAction.cover)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 34,
                      height: 46,
                      child: image == null
                          ? ColoredBox(color: tokens.surface3)
                          : Image(image: image, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    key: Key('import-edit-${row.rowIndex}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(
                      showCsvRowSheet(context, rowIndex: row.rowIndex),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.label.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          rowMeta(row),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.caption.copyWith(color: tokens.faint),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: verdict.chip == null
                      ? null
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: ShelfChip(
                            key: Key('import-chip-${row.rowIndex}'),
                            label: verdict.chip!,
                            kind: switch (verdict.chip) {
                              'Owned' => ShelfChipKind.ok,
                              'Check match' => ShelfChipKind.accent,
                              _ => ShelfChipKind.neutral,
                            },
                          ),
                        ),
                ),
                ShelfButton(
                  key: Key('import-action-${row.rowIndex}'),
                  label: verdict.action.label,
                  onPressed: () => unawaited(_action(row, verdict.action)),
                ),
                const SizedBox(width: 4),
                ShelfIconButton(
                  key: Key('import-remove-${row.rowIndex}'),
                  icon: Icons.delete_outline,
                  tooltip: 'Remove ${row.title} from the import',
                  onPressed: () => ref
                      .read(csvImportProvider.notifier)
                      .removeRow(row.rowIndex),
                ),
              ],
            ),
            if (info.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 46, top: 4),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    for (final part in info)
                      Text(
                        part.text,
                        style: style.caption.copyWith(
                          color: part.warning ? tokens.danger : tokens.muted,
                        ),
                      ),
                  ],
                ),
              ),
            if (row.duplicates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 46, top: 6),
                child: _Duplicates(
                  row: row,
                  open: _duplicatesOpen,
                  onToggle: () =>
                      setState(() => _duplicatesOpen = !_duplicatesOpen),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<({String text, bool warning})> _info(CsvPreviewRow row) {
    return [
      if (row.playtime != null)
        (text: '${_hours(row.playtime!)} h played', warning: false),
      if (row.reviewStars != null)
        (text: 'Rating: ${row.reviewStars}/10', warning: false),
      if (row.completedAt != null)
        (
          text: 'Completed: ${completedMonthLabel(row.completedAt!)}',
          warning: false,
        ),
      if (row.note != null && row.note!.isNotEmpty)
        (text: 'Note: ${row.note}', warning: false),
      if (row.review != null && row.review!.isNotEmpty)
        (text: 'Review: ${row.review}', warning: false),
      for (final warning in rowWarnings(row)) (text: warning, warning: true),
    ];
  }

  String _hours(double hours) => hours == hours.roundToDouble()
      ? hours.round().toString()
      : hours.toString();
}

class _Duplicates extends StatelessWidget {
  const _Duplicates({
    required this.row,
    required this.open,
    required this.onToggle,
  });

  final CsvPreviewRow row;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          key: Key('import-duplicates-${row.rowIndex}'),
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Row(
            children: [
              Icon(Icons.warning_amber, size: 14, color: tokens.accent),
              const SizedBox(width: 6),
              Text(
                'Already in your backlog (${row.duplicates.length})',
                style: style.caption.copyWith(color: tokens.accent),
              ),
              const Spacer(),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: tokens.muted,
              ),
            ],
          ),
        ),
        if (open)
          for (final duplicate in row.duplicates)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(duplicate.title, style: style.label),
                  const SizedBox(height: 4),
                  FieldDiffList(diffs: duplicate.diffs),
                ],
              ),
            ),
      ],
    );
  }
}
