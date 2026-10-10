import 'dart:async';
import 'dart:convert';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/csv_export.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/platform/file_saver.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// How many entries are turned into CSV before the progress is shown.
const _chunk = 200;

/// The export of the backlog as a CSV file: the entries, optionally of one
/// status and without the reviews and notes, saved where the user chooses.
class ExportPage extends StatelessWidget {
  const ExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('page-export'),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(28),
        child: ExportPanel(),
      ),
    );
  }
}

class ExportPanel extends ConsumerStatefulWidget {
  const ExportPanel({super.key});

  @override
  ConsumerState<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends ConsumerState<ExportPanel> {
  String? _status;
  bool _includeReviews = true;
  bool _exporting = false;
  int _processed = 0;
  int _total = 0;

  void _toast(String message) {
    if (mounted) showShelfToast(context, message);
  }

  Future<void> _export(List<BacklogEntry> entries) async {
    if (entries.isEmpty) {
      _toast('No backlog entries found to export');
      return;
    }
    final saver = ref.read(fileSaverProvider);
    final includeReviews = _includeReviews;
    setState(() {
      _exporting = true;
      _processed = 0;
      _total = entries.length;
    });
    try {
      final parts = <String>[];
      for (var start = 0; start < entries.length; start += _chunk) {
        final end = start + _chunk < entries.length
            ? start + _chunk
            : entries.length;
        parts.add(
          buildCsv(entries.sublist(start, end), includeReviews: includeReviews),
        );
        if (mounted) setState(() => _processed = end);
        await Future<void>.delayed(Duration.zero);
      }
      final saved = await saver.save(
        suggestedName: exportFileName(DateTime.now()),
        bytes: utf8.encode(parts.join('\n')),
      );
      if (saved) {
        _toast(
          'Successfully exported ${entries.length} '
          '${entries.length == 1 ? 'entry' : 'entries'}!',
        );
      }
    } on Object catch (error) {
      _toast(ApiException.from(error, 'Failed to export entries').message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final entries = ref.watch(entriesProvider(null));
    final statuses = ref.watch(
      filterOptionsProvider.select((options) => options.statuses),
    );
    final chosen = entriesWithStatus(entries.value ?? const [], _status);
    final count = entries.hasValue
        ? '${chosen.length} ${chosen.length == 1 ? 'game' : 'games'}'
        : entries.hasError
        ? 'Could not load your backlog'
        : 'Loading...';

    return ShelfSheet(
      title: 'Export backlog',
      description:
          'Save all your entries as a CSV file you can open in any '
          'spreadsheet.',
      width: ShelfSheetWidth.compact,
      onClose: () => context.go(AppRoutes.library),
      footer: ShelfSheetFooter(
        onCancel: _exporting ? null : () => context.go(AppRoutes.library),
        primary: ShelfButton(
          key: const Key('export-save'),
          label: _exporting ? 'Exporting...' : 'Save as CSV...',
          kind: ShelfButtonKind.primary,
          busy: _exporting,
          onPressed: entries.hasValue && !_exporting
              ? () => unawaited(_export(chosen))
              : null,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfFormGroup(
            title: 'Options',
            rows: [
              ShelfFormRow(
                label: 'Entries',
                description: count,
                control: ShelfMenuAnchor(
                  entries: [
                    ShelfMenuItem(
                      label: 'All statuses',
                      checked: _status == null,
                      onSelected: () => setState(() => _status = null),
                    ),
                    for (final status in statuses)
                      ShelfMenuItem(
                        label: status,
                        checked: _status == status,
                        onSelected: () => setState(() => _status = status),
                      ),
                  ],
                  builder: (context, controller) => SizedBox(
                    width: 170,
                    child: ShelfSelectTrigger(
                      key: const Key('export-status'),
                      text: _status ?? 'All statuses',
                      semanticLabel: 'Status',
                      onPressed: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                    ),
                  ),
                ),
              ),
              ShelfFormRow(
                label: 'Include reviews and notes',
                control: ShelfSwitch(
                  key: const Key('export-reviews'),
                  value: _includeReviews,
                  label: 'Include reviews and notes',
                  onChanged: _exporting
                      ? null
                      : (value) => setState(() => _includeReviews = value),
                ),
              ),
            ],
          ),
          if (_exporting && _total > 0) ...[
            const SizedBox(height: 14),
            ShelfProgressBar(value: _processed / _total),
            const SizedBox(height: 6),
            Text(
              'Processing entries: $_processed / $_total',
              key: const Key('export-progress'),
              textAlign: TextAlign.center,
              style: style.caption.copyWith(color: tokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}
