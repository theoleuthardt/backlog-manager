import 'dart:math' as math;

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/segmented.dart';
import 'package:backlog_manager/domain/format.dart';
import 'package:backlog_manager/domain/library_groups.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/domain/status_style.dart';
import 'package:backlog_manager/features/common/entries_gate.dart';
import 'package:backlog_manager/features/library/library_content.dart';
import 'package:backlog_manager/features/library/library_view.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _gutter = 28.0;

/// The library: a toolbar and the games in sections, as covers or as rows.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('page-library'),
      child: EntriesGate(
        builder: (context, entries) =>
            entries.isEmpty ? const _EmptyLibrary() : const _Library(),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your backlog is empty', style: style.page),
          const SizedBox(height: 6),
          Text(
            'Start by adding your first game!',
            style: style.caption.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 18),
          ShelfButton(
            label: 'Add a game',
            kind: ShelfButtonKind.primary,
            onPressed: () => context.go(AppRoutes.creationTool),
          ),
        ],
      ),
    );
  }
}

class _Library extends ConsumerWidget {
  const _Library();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(libraryContentProvider);
    if (content == null) return const SizedBox.shrink();
    final layout = ref.watch(libraryViewProvider.select((v) => v.layout));
    final serverUrl = ref.watch(serverUrlProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(content: content),
        Expanded(
          child: CustomScrollView(
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: 6)),
              for (final group in content.groups)
                ..._groupSlivers(group, layout, serverUrl),
              const SliverPadding(padding: EdgeInsets.only(bottom: 36)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _groupSlivers(
    LibraryGroup group,
    LibraryLayout layout,
    String? serverUrl,
  ) {
    return [
      SliverToBoxAdapter(child: _GroupHeader(group: group)),
      _GroupBody(group: group, layout: layout, serverUrl: serverUrl),
    ];
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.content});

  final LibraryContent content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final view = ref.watch(libraryViewProvider);
    final notifier = ref.read(libraryViewProvider.notifier);
    final muted = style.caption.copyWith(color: tokens.muted);

    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Library', style: style.page),
          Text('${content.shown} of ${content.total} games', style: muted),
          Text(
            '${formatCount(content.hoursToBeat.round())} h to beat',
            style: muted,
          ),
          ShelfSegmented<LibraryLayout>(
            segments: const [
              ShelfSegment(value: LibraryLayout.grid, label: 'Grid'),
              ShelfSegment(value: LibraryLayout.list, label: 'List'),
            ],
            value: view.layout,
            onChanged: notifier.setLayout,
          ),
          ShelfMenuAnchor(
            entries: [
              for (final option in SortOption.values)
                ShelfMenuItem(
                  label: option.label,
                  checked: option == view.sortBy,
                  onSelected: () => notifier.setSort(option),
                ),
            ],
            builder: (context, controller) => ShelfButton(
              label: 'Sort: ${view.sortBy.label}',
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
          ShelfIconButton(
            icon: view.direction == SortDirection.asc
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            tooltip: 'Sort direction',
            onPressed: notifier.toggleDirection,
          ),
          ShelfButton(
            label: 'Add game',
            icon: Icons.add,
            kind: ShelfButtonKind.primary,
            onPressed: () => context.go(AppRoutes.creationTool),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({required this.group});

  final LibraryGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final collapsed = ref.watch(
      libraryViewProvider.select((v) => v.isCollapsed(group.key)),
    );
    final dot = group.status == null
        ? tokens.accent
        : colorFromHex(statusColor(group.status!));

    return Padding(
      key: Key('group-${group.key}'),
      padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 12),
      child: GestureDetector(
        key: Key('group-toggle-${group.key}'),
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            ref.read(libraryViewProvider.notifier).toggleCollapsed(group.key),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              child: const SizedBox(width: 9, height: 9),
            ),
            const SizedBox(width: 10),
            Text(group.label, style: style.groupTitle),
            const SizedBox(width: 8),
            Text(
              '${group.entries.length}',
              style: style.caption.copyWith(color: tokens.muted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tokens.borderStrong,
                      tokens.borderStrong.withAlpha(0),
                    ],
                  ),
                ),
                child: const SizedBox(height: 1),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 18,
              color: tokens.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBody extends ConsumerWidget {
  const _GroupBody({
    required this.group,
    required this.layout,
    required this.serverUrl,
  });

  final LibraryGroup group;
  final LibraryLayout layout;
  final String? serverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(
      libraryViewProvider.select((v) => v.isCollapsed(group.key)),
    );
    final visible = ref.watch(
      libraryViewProvider.select((v) => v.visibleIn(group.key)),
    );
    if (collapsed || group.entries.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final shownCount = math.min(visible, group.entries.length);
    final hidden = group.entries.length - shownCount;
    final showStatus =
        ref.watch(libraryViewProvider.select((v) => v.sortBy)) !=
        SortOption.status;

    final content = layout == LibraryLayout.grid
        ? SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            sliver: ShelfCoverSliverGrid(
              extraHeight: 36,
              itemCount: shownCount,
              itemBuilder: (context, index) => _Tile(
                entry: group.entries[index],
                serverUrl: serverUrl,
                showStatus: showStatus,
              ),
            ),
          )
        : SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            sliver: SliverList.builder(
              itemCount: shownCount,
              itemBuilder: (context, index) =>
                  _Row(entry: group.entries[index]),
            ),
          );

    return SliverMainAxisGroup(
      slivers: [
        content,
        if (hidden > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ShelfButton(
                  label:
                      'Show ${math.min(groupPageSize, hidden)} more ($hidden hidden)',
                  kind: ShelfButtonKind.quiet,
                  onPressed: () => ref
                      .read(libraryViewProvider.notifier)
                      .showMore(group.key),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String? _playtimeLabel(BacklogEntry entry) {
  final played = entry.playtime;
  final toBeat = entry.mainTime;
  if (toBeat != null) {
    return '${formatHours(played ?? 0)} / ${formatHours(toBeat)} h';
  }
  if (played != null) return '${formatHours(played)} h';
  return null;
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.entry,
    required this.serverUrl,
    required this.showStatus,
  });

  final BacklogEntry entry;
  final String? serverUrl;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final toBeat = entry.mainTime;
    return ShelfCover(
      title: entry.title,
      image: entryImage(serverUrl, entry.imageLink),
      meta: _playtimeLabel(entry),
      progress: toBeat == null || toBeat <= 0
          ? null
          : (entry.playtime ?? 0) / toBeat,
      overlay: Stack(
        children: [
          if (showStatus)
            Positioned(
              left: 8,
              bottom: 8,
              child: _StatusPill(status: entry.status),
            ),
          if (entry.inSharedSpace)
            const Positioned(right: 8, top: 8, child: _SharedBadge()),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.scrim,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorFromHex(statusColor(status)),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 6, height: 6),
            ),
            const SizedBox(width: 5),
            Text(status, style: style.label.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _SharedBadge extends StatelessWidget {
  const _SharedBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return Tooltip(
      message: 'Also in your shared space',
      child: DecoratedBox(
        decoration: BoxDecoration(color: tokens.scrim, shape: BoxShape.circle),
        child: const Padding(
          padding: EdgeInsets.all(5),
          child: Icon(Icons.people, size: 13, color: Colors.white),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final BacklogEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return DecoratedBox(
      key: Key('library-row-${entry.id}'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                entry.title,
                style: style.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ShelfChip(label: entry.status),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                entry.genre.firstOrNull ?? '',
                style: style.caption.copyWith(color: tokens.muted),
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                _playtimeLabel(entry) ?? '',
                textAlign: TextAlign.right,
                style: style.caption.copyWith(color: tokens.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
