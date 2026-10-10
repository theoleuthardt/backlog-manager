import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/csv_import.dart';
import 'package:backlog_manager/features/import_csv/csv_import_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which column of the file holds which field, and the button that starts
/// the preview.
class CsvMappingPanel extends ConsumerWidget {
  const CsvMappingPanel({
    required this.state,
    required this.onPreview,
    super.key,
  });

  final CsvImportState state;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final controller = ref.read(csvImportProvider.notifier);
    final headers = state.headers ?? const {};
    final letters = sortedColumnLetters(headers);
    final config = state.config;
    final previewing = state.phase == CsvImportPhase.previewing;
    final enabled = !state.busy;

    Widget select({
      required String label,
      required String? value,
      required ValueChanged<String?> onChanged,
      bool optional = false,
    }) {
      return ShelfFormRow(
        label: label,
        control: ShelfMenuAnchor(
          entries: [
            if (optional)
              ShelfMenuItem(
                label: '-- none --',
                checked: value == null,
                onSelected: () => onChanged(null),
              ),
            for (final letter in letters)
              ShelfMenuItem(
                label: columnLabel(letter, headers),
                checked: value == letter,
                onSelected: () => onChanged(letter),
              ),
          ],
          builder: (context, menu) => SizedBox(
            width: 190,
            child: ShelfSelectTrigger(
              key: Key(
                'import-column-${label.toLowerCase().replaceAll(' ', '-')}',
              ),
              text: value == null ? '-- none --' : columnLabel(value, headers),
              semanticLabel: label,
              onPressed: !enabled
                  ? () {}
                  : () => menu.isOpen ? menu.close() : menu.open(),
            ),
          ),
        ),
      );
    }

    Widget checks({
      required String label,
      required String description,
      required List<String> selected,
      required void Function(String letter, bool on) onToggle,
    }) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: style.label),
            const SizedBox(height: 2),
            Text(
              description,
              style: style.caption.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final letter in letters)
                  ShelfCheckbox(
                    key: Key('import-$label-$letter'),
                    value: selected.contains(letter),
                    label: columnLabel(letter, headers),
                    onChanged: enabled ? (on) => onToggle(letter, on) : null,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfFormGroup(
          title: 'Column mapping',
          description: 'Pick which column holds which field.',
          rows: [
            select(
              label: 'Title',
              value: config.titleColumn,
              onChanged: (v) =>
                  controller.setConfig(config.copyWith(titleColumn: v)),
            ),
            select(
              label: 'Genre',
              value: config.genreColumn,
              onChanged: (v) =>
                  controller.setConfig(config.copyWith(genreColumn: v)),
            ),
            select(
              label: 'Platform',
              value: config.platformColumn,
              onChanged: (v) =>
                  controller.setConfig(config.copyWith(platformColumn: v)),
            ),
            select(
              label: 'Status',
              value: config.statusColumn,
              onChanged: (v) =>
                  controller.setConfig(config.copyWith(statusColumn: v)),
            ),
            select(
              label: 'Playtime',
              value: config.playtimeColumn,
              optional: true,
              onChanged: (v) => controller.setConfig(
                config.copyWith(playtimeColumn: v, clearPlaytime: v == null),
              ),
            ),
            select(
              label: 'Rating',
              value: config.ratingColumn,
              optional: true,
              onChanged: (v) => controller.setConfig(
                config.copyWith(ratingColumn: v, clearRating: v == null),
              ),
            ),
            select(
              label: 'Completed date',
              value: config.completedAtColumn,
              optional: true,
              onChanged: (v) => controller.setConfig(
                config.copyWith(
                  completedAtColumn: v,
                  clearCompletedAt: v == null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              checks(
                label: 'Review columns',
                description:
                    'Merged into the review text, for example "Reason '
                    'finished".',
                selected: config.reviewColumns,
                onToggle: (letter, on) => controller.setConfig(
                  config.withReviewColumn(letter, on: on),
                ),
              ),
              checks(
                label: 'Note columns',
                description:
                    'Merged as "Header: Value" so short yes or no columns '
                    'keep their context.',
                selected: config.noteColumns,
                onToggle: (letter, on) =>
                    controller.setConfig(config.withNoteColumn(letter, on: on)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ShelfButton(
          key: const Key('import-preview'),
          label: previewing
              ? previewLabel(state.processed, state.total)
              : state.hasPreview
              ? 'Preview again'
              : 'Preview import',
          kind: ShelfButtonKind.primary,
          busy: previewing,
          onPressed: enabled ? onPreview : null,
        ),
      ],
    );
  }
}
