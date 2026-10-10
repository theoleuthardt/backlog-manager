import 'dart:async';

import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/csv_import.dart';
import 'package:backlog_manager/features/add_game/cover_picker_sheet.dart';
import 'package:backlog_manager/features/add_game/wrong_game_sheet.dart';
import 'package:backlog_manager/features/import_csv/csv_import_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the editor of one preview row.
Future<void> showCsvRowSheet(BuildContext context, {required int rowIndex}) {
  return showShelfSheet<void>(
    context,
    builder: (_) => CsvRowSheet(rowIndex: rowIndex),
  );
}

/// Edits one row of the preview: title, genre, platforms, status and owned,
/// and the same fixes as the row (right game, cover) plus removing it. Every
/// change applies at once.
class CsvRowSheet extends ConsumerStatefulWidget {
  const CsvRowSheet({required this.rowIndex, super.key});

  final int rowIndex;

  @override
  ConsumerState<CsvRowSheet> createState() => _CsvRowSheetState();
}

class _CsvRowSheetState extends ConsumerState<CsvRowSheet> {
  late final TextEditingController _title;
  late final TextEditingController _genre;
  late final TextEditingController _platform;

  @override
  void initState() {
    super.initState();
    final row = ref.read(csvRowProvider(widget.rowIndex));
    _title = TextEditingController(text: row?.title ?? '');
    _genre = TextEditingController(text: row?.genre ?? '');
    _platform = TextEditingController(text: row?.platform.join(', ') ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _genre.dispose();
    _platform.dispose();
    super.dispose();
  }

  CsvPreviewRow? get _row => ref.read(csvRowProvider(widget.rowIndex));

  void _edit({String? title, String? genre, List<String>? platform}) {
    final row = _row;
    if (row == null) return;
    ref
        .read(csvImportProvider.notifier)
        .updateRow(
          row.copyWith(title: title, genre: genre, platform: platform),
        );
  }

  Future<void> _wrongGame() async {
    final row = _row;
    if (row == null) return;
    final result = await showWrongGameSheet(context, initialQuery: row.title);
    if (result == null || !mounted) return;
    ref.read(csvImportProvider.notifier).chooseGame(row.rowIndex, result);
    final updated = _row;
    if (updated == null) return;
    _title.text = updated.title;
    _genre.text = updated.genre;
  }

  Future<void> _cover() async {
    final row = _row;
    if (row == null) return;
    final url = await showCoverPicker(context, initialQuery: row.title);
    final current = _row;
    if (url == null || current == null || !mounted) return;
    ref
        .read(csvImportProvider.notifier)
        .updateRow(current.copyWith(imageLink: url));
  }

  @override
  Widget build(BuildContext context) {
    final row = ref.watch(csvRowProvider(widget.rowIndex));
    final statuses = ref.watch(
      filterOptionsProvider.select((options) => options.statuses),
    );
    if (row == null) {
      return const SizedBox.shrink();
    }
    final options = statuses.contains(row.status)
        ? statuses
        : [...statuses, row.status];

    return ShelfSheet(
      title: 'Edit row',
      description: 'Changes apply to what is imported, not to the file.',
      footer: ShelfSheetFooter(
        cancelLabel: 'Remove from import',
        onCancel: () {
          ref.read(csvImportProvider.notifier).removeRow(widget.rowIndex);
          Navigator.of(context).maybePop();
        },
        primary: ShelfButton(
          key: const Key('import-row-done'),
          label: 'Done',
          kind: ShelfButtonKind.primary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfField(
            key: const Key('import-row-title'),
            label: 'Title',
            controller: _title,
            onChanged: (text) => _edit(title: text),
          ),
          const SizedBox(height: 10),
          ShelfField(
            key: const Key('import-row-genre'),
            label: 'Genre',
            controller: _genre,
            onChanged: (text) => _edit(genre: text),
          ),
          const SizedBox(height: 10),
          ShelfField(
            key: const Key('import-row-platform'),
            label: 'Platform',
            hint: 'Separate platforms with commas',
            controller: _platform,
            onChanged: (text) => _edit(platform: platformsFromText(text)),
          ),
          const SizedBox(height: 10),
          ShelfFormRow(
            label: 'Status',
            control: ShelfMenuAnchor(
              entries: [
                for (final status in options)
                  ShelfMenuItem(
                    label: status,
                    checked: row.status == status,
                    onSelected: () => ref
                        .read(csvImportProvider.notifier)
                        .updateRow(row.copyWith(status: status)),
                  ),
              ],
              builder: (context, menu) => SizedBox(
                width: 190,
                child: ShelfSelectTrigger(
                  key: const Key('import-row-status'),
                  text: row.status,
                  semanticLabel: 'Status',
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                ),
              ),
            ),
          ),
          ShelfFormRow(
            label: 'Owned',
            control: ShelfSwitch(
              key: const Key('import-row-owned'),
              value: row.owned,
              label: 'Owned',
              onChanged: (value) => ref
                  .read(csvImportProvider.notifier)
                  .updateRow(row.copyWith(owned: value)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ShelfButton(
                key: const Key('import-row-wrong-game'),
                label: 'Wrong game',
                onPressed: () => unawaited(_wrongGame()),
              ),
              const SizedBox(width: 8),
              ShelfButton(
                key: const Key('import-row-cover'),
                label: 'Choose cover',
                onPressed: () => unawaited(_cover()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
