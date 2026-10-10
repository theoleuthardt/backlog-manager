import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/diff_fields.dart';
import 'package:flutter/material.dart';

const _fieldLabels = {
  'genre': 'Genre',
  'platform': 'Platform',
  'status': 'Status',
  'owned': 'Owned',
  'playtime': 'Playtime',
  'review_stars': 'Review Stars',
  'note': 'Note',
  'completed_at': 'Completed At',
};

/// What differs between an existing entry and the one about to be created:
/// per field the old value with a minus and the new one with a plus.
class FieldDiffList extends StatelessWidget {
  const FieldDiffList({required this.diffs, super.key});

  final List<FieldDiffEntry> diffs;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    if (diffs.isEmpty) {
      return Text(
        'No differences from the existing entry.',
        style: style.caption.copyWith(color: tokens.muted),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final diff in diffs) ...[
              ColoredBox(
                color: tokens.surface2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    (_fieldLabels[diff.field] ?? diff.field).toUpperCase(),
                    style: style.keyHint.copyWith(color: tokens.muted),
                  ),
                ),
              ),
              _line(
                key: Key('diff-${diff.field}-old'),
                sign: '-',
                value: diff.existing,
                color: tokens.danger,
                style: style,
              ),
              _line(
                key: Key('diff-${diff.field}-new'),
                sign: '+',
                value: diff.proposed,
                color: tokens.success,
                style: style,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line({
    required Key key,
    required String sign,
    required String value,
    required Color color,
    required ShelfTextStyles style,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        '$sign ${value.isEmpty ? '(empty)' : value}',
        style: style.caption.copyWith(color: color),
      ),
    );
  }
}
