import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/domain/csv_import.dart';
import 'package:backlog_manager/features/import_csv/csv_import_controller.dart';
import 'package:flutter/material.dart';

/// The rows the last import skipped, collapsed to a heading until it is
/// opened.
class SkippedRows extends StatefulWidget {
  const SkippedRows({required this.rows, super.key});

  final List<SkippedRow> rows;

  @override
  State<SkippedRows> createState() => _SkippedRowsState();
}

class _SkippedRowsState extends State<SkippedRows> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      key: const Key('import-skipped'),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(ShelfRadius.card),
        border: Border.all(color: tokens.danger),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShelfPressable(
              key: const Key('import-skipped-toggle'),
              semanticLabel: skippedHeading(widget.rows.length),
              onPressed: () => setState(() => _open = !_open),
              builder: (context, state) => Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: tokens.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      skippedHeading(widget.rows.length),
                      style: style.label.copyWith(color: tokens.danger),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: tokens.muted,
                  ),
                ],
              ),
            ),
            if (_open) ...[
              const SizedBox(height: 8),
              for (final row in widget.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: row.title,
                          style: style.label.copyWith(color: tokens.foreground),
                        ),
                        TextSpan(
                          text: ' - ${row.reason}',
                          style: style.caption.copyWith(color: tokens.muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
