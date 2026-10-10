import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/creation_form.dart';
import 'package:backlog_manager/domain/diff_fields.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/creation/field_diff_list.dart';
import 'package:flutter/material.dart';

/// Asks whether to create [proposed] although [existing] looks like the same
/// game; the future is true for "Add Anyway".
Future<bool> confirmDuplicate(
  BuildContext context, {
  required List<BacklogEntry> existing,
  required NewEntry proposed,
}) async {
  final result = await showShelfSheet<bool>(
    context,
    builder: (_) => DuplicateSheet(existing: existing, proposed: proposed),
  );
  return result ?? false;
}

/// "Duplicate found": the entries that look the same, each with what differs
/// from the new one.
class DuplicateSheet extends StatelessWidget {
  const DuplicateSheet({
    required this.existing,
    required this.proposed,
    super.key,
  });

  final List<BacklogEntry> existing;
  final NewEntry proposed;

  DiffableFields _fields(BacklogEntry entry) => DiffableFields(
    genre: entry.genre,
    platform: entry.platform,
    status: entry.status,
    owned: entry.owned,
    playtime: entry.playtime,
    reviewStars: entry.reviewStars,
    note: entry.note,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final proposedFields = DiffableFields(
      genre: proposed.genre,
      platform: proposed.platform,
      status: proposed.status,
      owned: proposed.owned,
      playtime: proposed.playtime,
      reviewStars: proposed.reviewStars,
      note: proposed.note,
    );
    return ShelfSheet(
      title: 'Duplicate found',
      description: existing.length == 1
          ? 'This game is already in your backlog.'
          : 'These games are already in your backlog.',
      width: ShelfSheetWidth.standard,
      footer: ShelfSheetFooter(
        cancelLabel: 'Do not Add',
        onCancel: () => Navigator.of(context).pop(false),
        primary: ShelfButton(
          key: const Key('duplicate-add-anyway'),
          label: 'Add Anyway',
          kind: ShelfButtonKind.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in existing)
            Padding(
              key: Key('duplicate-${entry.id}'),
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: style.control),
                  const SizedBox(height: 2),
                  Text(
                    'Existing entry compared with the one you are adding',
                    style: style.caption.copyWith(color: tokens.faint),
                  ),
                  const SizedBox(height: 8),
                  FieldDiffList(
                    diffs: computeFieldDiffs(_fields(entry), proposedFields),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
