import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/creation_form.dart';
import 'package:backlog_manager/domain/diff_fields.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/creation/field_diff_list.dart';
import 'package:flutter/material.dart';

/// What the user chose for a game that looks like one of the backlog.
enum DuplicateChoice { skip, add, addWithoutSteamAppId }

/// Whether one of [existing] has the Steam App ID of [proposed]: a backlog
/// holds each Steam App ID once (the Steam playtime sync relies on it), so
/// such a game can only be added without it.
bool sharesSteamAppId(List<BacklogEntry> existing, NewEntry proposed) {
  final appId = proposed.steamAppId;
  return appId != null && existing.any((entry) => entry.steamAppId == appId);
}

/// Asks whether to create [proposed] although [existing] looks like the same
/// game: "Add Anyway", or "Add without Steam App ID" when one of them has the
/// same Steam App ID ([sharesSteamAppId]).
Future<DuplicateChoice> confirmDuplicate(
  BuildContext context, {
  required List<BacklogEntry> existing,
  required NewEntry proposed,
}) async {
  final result = await showShelfSheet<DuplicateChoice>(
    context,
    builder: (_) => DuplicateSheet(existing: existing, proposed: proposed),
  );
  return result ?? DuplicateChoice.skip;
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
    final sameAppId = sharesSteamAppId(existing, proposed);
    final already = existing.length == 1
        ? 'This game is already in your backlog.'
        : 'These games are already in your backlog.';
    return ShelfSheet(
      title: 'Duplicate found',
      description: sameAppId
          ? '$already It has the same Steam App ID, which a backlog holds '
                'once, so the new entry can only be added without it.'
          : already,
      width: ShelfSheetWidth.standard,
      footer: ShelfSheetFooter(
        cancelLabel: 'Do not Add',
        onCancel: () => Navigator.of(context).pop(DuplicateChoice.skip),
        primary: ShelfButton(
          key: const Key('duplicate-add-anyway'),
          label: sameAppId ? 'Add without Steam App ID' : 'Add Anyway',
          kind: ShelfButtonKind.primary,
          onPressed: () => Navigator.of(context).pop(
            sameAppId
                ? DuplicateChoice.addWithoutSteamAppId
                : DuplicateChoice.add,
          ),
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
