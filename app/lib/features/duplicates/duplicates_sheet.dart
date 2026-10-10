import 'dart:async';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/backlog_scope.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/duplicates.dart';
import 'package:backlog_manager/domain/format.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/creation/field_diff_list.dart';
import 'package:backlog_manager/features/library/library_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the list of the games that are in the backlog more than once.
Future<void> showDuplicatesSheet(BuildContext context) {
  return showShelfSheet<void>(context, builder: (_) => const DuplicatesSheet());
}

/// Every game that is in the backlog more than once, with what its entries
/// differ in, and a way to delete the entries that are too many by hand. The
/// first (oldest) entry of a group is the one the others are compared with.
class DuplicatesSheet extends ConsumerWidget {
  const DuplicatesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final entries = ref.watch(entriesProvider(ref.watch(backlogScopeProvider)));
    final groups = findDuplicateGroups(entries.value ?? const []);
    final count = groups.fold<int>(0, (sum, g) => sum + g.entries.length);

    return ShelfSheet(
      title: 'Duplicate games',
      description:
          'Games that are in your backlog more than once, by title or Steam '
          'App ID. Delete the entries you do not need.',
      width: ShelfSheetWidth.wide,
      child: entries.isLoading && !entries.hasValue
          ? Text('Loading...', style: style.body.copyWith(color: tokens.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  duplicatesHeading(groups.length, count),
                  key: const Key('duplicates-heading'),
                  style: style.label.copyWith(color: tokens.muted),
                ),
                for (final group in groups) ...[
                  const SizedBox(height: 14),
                  _GroupCard(group: group),
                ],
              ],
            ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final DuplicateGroup group;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final kept = group.entries.first;

    return DecoratedBox(
      key: Key('duplicate-group-${kept.id}'),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(ShelfRadius.card),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.groupTitle,
                  ),
                ),
                Text(
                  group.reason,
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ],
            ),
            for (final entry in group.entries) ...[
              const SizedBox(height: 10),
              _EntryRow(entry: entry, kept: entry.id == kept.id ? null : kept),
            ],
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, required this.kept});

  final BacklogEntry entry;

  /// The entry this one is compared with, null for that entry itself.
  final BacklogEntry? kept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final serverUrl = ref.watch(serverUrlProvider).value;
    final image = entryImage(serverUrl, entry.imageLink);
    final played = entry.playtime;
    final meta = [
      entry.status,
      if (entry.platform.isNotEmpty) entry.platform.join(', '),
      if (played != null) '${formatHours(played)} h played',
      if (entry.steamAppId != null) 'Steam ${entry.steamAppId}',
    ].join(' · ');
    final diffs = kept == null ? null : diffAgainst(kept!, entry);

    return Column(
      key: Key('duplicate-entry-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 34,
                height: 46,
                child: image == null
                    ? ColoredBox(color: tokens.surface3)
                    : Image(image: image, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kept == null ? '${entry.title} (oldest)' : entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.label.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
            ShelfButton(
              key: Key('duplicate-delete-${entry.id}'),
              label: 'Delete',
              kind: ShelfButtonKind.danger,
              onPressed: () => unawaited(
                LibraryActions(context, ref).deleteEntries([entry]),
              ),
            ),
          ],
        ),
        if (diffs != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: FieldDiffList(diffs: diffs),
          ),
        ],
      ],
    );
  }
}
