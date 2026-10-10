import 'dart:async';

import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/csv_import.dart';
import 'package:backlog_manager/features/import_csv/csv_import_controller.dart';
import 'package:backlog_manager/features/import_csv/csv_mapping_panel.dart';
import 'package:backlog_manager/features/import_csv/csv_preview_table.dart';
import 'package:backlog_manager/features/import_csv/skipped_rows.dart';
import 'package:backlog_manager/platform/csv_file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The CSV import: choose a file (or drop it on the window), map its columns,
/// preview the matches and import them.
class ImportCsvPage extends ConsumerStatefulWidget {
  const ImportCsvPage({super.key});

  @override
  ConsumerState<ImportCsvPage> createState() => _ImportCsvPageState();
}

class _ImportCsvPageState extends ConsumerState<ImportCsvPage> {
  bool _dragging = false;

  void _toast(String? message) {
    if (message != null && mounted) showShelfToast(context, message);
  }

  Future<void> _load(PickedFile file) async {
    final controller = ref.read(csvImportProvider.notifier);
    try {
      final text = decodeCsvFile(file.name, await file.readBytes());
      _toast(await controller.loadFile(file.name, text));
    } on CsvFileException catch (error) {
      _toast(error.message);
    } on Object {
      _toast('Failed to read CSV file');
    }
  }

  Future<void> _choose() async {
    final file = await ref.read(csvFilePickerProvider).pick();
    if (file != null) await _load(file);
  }

  Future<void> _preview() async {
    _toast(await ref.read(csvImportProvider.notifier).preview());
  }

  Future<void> _submit() async {
    _toast(await ref.read(csvImportProvider.notifier).submit());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(csvImportProvider);
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        if (state.busy || details.files.isEmpty) return;
        unawaited(_load(PickedFile.fromXFile(details.files.first)));
      },
      child: DecoratedBox(
        key: const Key('page-import'),
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: _dragging ? Border.all(color: tokens.accent, width: 2) : null,
        ),
        child: state.hasFile
            ? _Loaded(
                state: state,
                onChoose: _choose,
                onPreview: _preview,
                onSubmit: _submit,
              )
            : _Empty(state: state, onChoose: _choose),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.state, required this.onChoose});

  final CsvImportState state;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final reading = state.phase == CsvImportPhase.readingHeaders;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Import backlog from CSV',
                textAlign: TextAlign.center,
                style: style.page,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a CSV file, pick which columns hold which field, then '
                'preview what would be imported before anything is written '
                'to your backlog.',
                textAlign: TextAlign.center,
                style: style.body.copyWith(color: tokens.muted),
              ),
              const SizedBox(height: 20),
              Center(
                child: ShelfButton(
                  key: const Key('import-choose'),
                  label: reading ? 'Reading file...' : 'Choose CSV file...',
                  kind: ShelfButtonKind.primary,
                  busy: reading,
                  onPressed: reading ? null : onChoose,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'or drop a .csv file on this window',
                textAlign: TextAlign.center,
                style: style.caption.copyWith(color: tokens.faint),
              ),
              if (state.skipped.isNotEmpty) ...[
                const SizedBox(height: 24),
                SkippedRows(rows: state.skipped),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.state,
    required this.onChoose,
    required this.onPreview,
    required this.onSubmit,
  });

  final CsvImportState state;
  final VoidCallback onChoose;
  final VoidCallback onPreview;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final controller = ref.read(csvImportProvider.notifier);
    final rows = state.rows;
    final running =
        state.phase == CsvImportPhase.previewing ||
        state.phase == CsvImportPhase.submitting;
    final submitting = state.phase == CsvImportPhase.submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ShelfChip(
                key: const Key('import-file'),
                label: state.fileName ?? '',
                kind: ShelfChipKind.accent,
              ),
              ShelfButton(
                key: const Key('import-choose-other'),
                label: 'Choose another file',
                onPressed: state.busy ? null : onChoose,
              ),
              if (state.hasPreview)
                Text(
                  rowsSummary(rows),
                  key: const Key('import-summary'),
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              if (running && state.total != null)
                SizedBox(
                  width: 160,
                  child: ShelfProgressBar(
                    value: (state.processed ?? 0) / state.total!,
                  ),
                ),
              ShelfButton(
                key: const Key('import-cancel'),
                label: 'Cancel',
                onPressed: running ? controller.cancel : controller.reset,
              ),
              if (state.hasPreview)
                ShelfButton(
                  key: const Key('import-submit'),
                  label: submitting
                      ? submitLabel(state.processed, state.total)
                      : importLabel(rows.length),
                  kind: ShelfButtonKind.primary,
                  busy: submitting,
                  onPressed: state.busy || rows.isEmpty ? null : onSubmit,
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: CsvMappingPanel(state: state, onPreview: onPreview),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: state.hasPreview
                      ? const CsvPreviewTable()
                      : Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Nothing is written until you import. Preview the '
                            'matches first.',
                            style: style.body.copyWith(color: tokens.muted),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
