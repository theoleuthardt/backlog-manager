import 'dart:async';
import 'dart:math' as math;

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/backlog_scope.dart';
import 'package:backlog_manager/data/drag_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/data/selection_providers.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/domain/format.dart';
import 'package:backlog_manager/domain/library_groups.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:backlog_manager/domain/status_style.dart';
import 'package:backlog_manager/features/common/entries_gate.dart';
import 'package:backlog_manager/features/duplicates/duplicates_sheet.dart';
import 'package:backlog_manager/features/library/entry_drag.dart';
import 'package:backlog_manager/features/library/filter_bar.dart';
import 'package:backlog_manager/features/library/library_actions.dart';
import 'package:backlog_manager/features/library/library_content.dart';
import 'package:backlog_manager/features/library/library_view.dart';
import 'package:backlog_manager/features/library/selection_bar.dart';
import 'package:backlog_manager/features/space/member_progress.dart';
import 'package:backlog_manager/features/space/space_toolbar.dart';
import 'package:backlog_manager/features/steam/steam_sync_button.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _gutter = 28.0;

/// The library: a toolbar and the games in sections, as covers or as rows.
///
/// With a [space] it is the library of the shared space: the header of the
/// space replaces the title, and covers show the progress of both members.
class LibraryPage extends StatelessWidget {
  const LibraryPage({this.space, super.key});

  final Space? space;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('page-library'),
      child: EntriesGate(
        builder: (context, entries) => entries.isEmpty
            ? _EmptyLibrary(shared: space != null)
            : _Library(space: space),
      ),
    );
  }
}

class _EmptyLibrary extends ConsumerWidget {
  const _EmptyLibrary({required this.shared});

  final bool shared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            shared ? 'Your shared space is empty' : 'Your backlog is empty',
            style: style.page,
          ),
          const SizedBox(height: 6),
          Text(
            shared
                ? 'Add a Steam game to start your co-op backlog.'
                : 'Start by adding your first game!',
            style: style.caption.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 18),
          ShelfButton(
            key: const Key('library-empty-add'),
            label: shared ? 'Add Steam game' : 'Add a game',
            kind: ShelfButtonKind.primary,
            onPressed: ref.read(addGameRequestProvider.notifier).request,
          ),
        ],
      ),
    );
  }
}

class _Library extends ConsumerStatefulWidget {
  const _Library({this.space});

  final Space? space;

  @override
  ConsumerState<_Library> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<_Library> {
  String? _reportedCount;
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  final _headerKeys = <String, GlobalKey>{};
  late final LibraryDrag _drag = LibraryDrag(
    ref: ref,
    context: context,
    groups: () => ref.read(libraryContentProvider)?.groups ?? const [],
    headerKeys: _headerKeys,
    viewportKey: _viewportKey,
    scroll: _scroll,
  );

  @override
  void dispose() {
    _drag.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _report(String counts) {
    if (counts == _reportedCount) return;
    _reportedCount = counts;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shellStatusProvider.notifier).update(counts: counts);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(libraryContentProvider);
    if (content == null) return const SizedBox.shrink();
    final active = ref.watch(activeFilterCountProvider);
    final selection = ref.watch(selectionProvider);
    final space = widget.space;
    final filterNote = active == 0
        ? ''
        : ' · $active ${active == 1 ? 'filter' : 'filters'}';
    _report(
      selection.active
          ? '${selection.ids.length} of ${content.shown} games selected'
                '$filterNote'
          : space != null && content.shown == content.total
          ? '${sharedGamesLabel(content.total)}$filterNote'
          : '${content.shown} of ${content.total} '
                '${space == null ? 'games' : 'shared games'}$filterNote',
    );
    final layout = ref.watch(libraryViewProvider.select((v) => v.layout));
    final serverUrl = ref.watch(serverUrlProvider).value;

    _headerKeys.removeWhere(
      (key, _) => !content.groups.any((group) => group.key == key),
    );

    return LibraryActionsScope(
      actions: LibraryActions(context, ref),
      child: LibraryDragScope(
        drag: _drag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selection.active)
              const SelectionBar(gutter: _gutter)
            else
              _Toolbar(content: content, space: space),
            if (space != null) SpaceNotice(space: space),
            const FilterBar(gutter: _gutter),
            Expanded(
              child: SizedBox.expand(
                key: _viewportKey,
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    const SliverPadding(padding: EdgeInsets.only(top: 6)),
                    for (final group in content.groups)
                      ..._groupSlivers(group, layout, serverUrl),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 36)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupSlivers(
    LibraryGroup group,
    LibraryLayout layout,
    String? serverUrl,
  ) {
    return [
      SliverToBoxAdapter(
        child: KeyedSubtree(
          key: _headerKeys.putIfAbsent(group.key, GlobalKey.new),
          child: _GroupHeader(group: group),
        ),
      ),
      _GroupBody(group: group, layout: layout, serverUrl: serverUrl),
    ];
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.content, this.space});

  final LibraryContent content;
  final Space? space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final muted = style.caption.copyWith(color: tokens.muted);

    final space = this.space;
    final selectButton = ShelfButton(
      key: const Key('select-toggle'),
      label: 'Select',
      icon: Icons.checklist,
      onPressed: ref.read(selectionProvider.notifier).begin,
    );
    final addButton = ShelfButton(
      key: const Key('add-game-button'),
      label: space == null ? 'Add game' : '+ Add Steam game',
      icon: space == null ? Icons.add : null,
      kind: ShelfButtonKind.primary,
      onPressed: ref.read(addGameRequestProvider.notifier).request,
    );

    if (space != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 8),
        child: Wrap(
          spacing: 14,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MemberAvatars(space: space),
            Text('Co-op backlog', style: style.page.copyWith(fontSize: 18)),
            Text(space.caption, key: const Key('space-caption'), style: muted),
            SpaceControls(space: space),
            selectButton,
            addButton,
          ],
        ),
      );
    }

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
          selectButton,
          if (ref.watch(sessionUserProvider)?.hasSteamId ?? false)
            const SteamSyncButton(),
          ShelfButton(
            key: const Key('igdb-sync-button'),
            label: 'Sync IGDB',
            icon: Icons.bolt,
            onPressed: ref.read(igdbSyncRequestProvider.notifier).request,
          ),
          ShelfIconButton(
            key: const Key('duplicates-button'),
            icon: Icons.content_copy,
            tooltip: 'Find duplicate games',
            onPressed: () => unawaited(showDuplicatesSheet(context)),
          ),
          addButton,
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
    final dropTarget = ref.watch(
      dragProvider.select((drag) => drag.overGroupKey == group.key),
    );

    return Padding(
      key: Key('group-${group.key}'),
      padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 12),
      child: DecoratedBox(
        key: dropTarget ? const Key('drop-target') : null,
        decoration: BoxDecoration(
          color: dropTarget ? tokens.accentSoft : null,
          borderRadius: BorderRadius.circular(ShelfRadius.card),
          border: Border.all(
            color: dropTarget ? tokens.accent : Colors.transparent,
            width: 2,
          ),
        ),
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
    if (collapsed) return const SliverToBoxAdapter(child: SizedBox.shrink());
    if (group.entries.isEmpty) {
      return SliverToBoxAdapter(child: _DropHint(group: group));
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
              extraHeight: ref.watch(backlogScopeProvider) == null ? 36 : 80,
              itemCount: shownCount,
              itemBuilder: (context, index) => _EntryTarget(
                key: ValueKey('tile-${group.entries[index].id}'),
                entry: group.entries[index],
                builder: (context, selected, selecting, onTap) => _Tile(
                  entry: group.entries[index],
                  serverUrl: serverUrl,
                  showStatus: showStatus,
                  selected: selected,
                  selecting: selecting,
                  onTap: onTap,
                ),
              ),
            ),
          )
        : SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            sliver: SliverList.builder(
              itemCount: shownCount,
              itemBuilder: (context, index) => _EntryTarget(
                key: ValueKey('row-${group.entries[index].id}'),
                entry: group.entries[index],
                builder: (context, selected, selecting, onTap) => _Row(
                  entry: group.entries[index],
                  selected: selected,
                  selecting: selecting,
                  onTap: onTap,
                ),
              ),
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

/// The slim placeholder of an empty group that takes a drop; it only shows
/// while a game is dragged.
class _DropHint extends ConsumerWidget {
  const _DropHint({required this.group});

  final LibraryGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dragging = ref.watch(dragProvider.select((drag) => drag.active));
    if (!group.droppable || !dragging) return const SizedBox.shrink();
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final status = group.status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: DecoratedBox(
        key: const Key('drop-hint'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ShelfRadius.card),
          border: Border.all(color: tokens.borderStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              status == null
                  ? 'Drop a game here to add it to ${group.label}'
                  : 'Drop a game here to mark it as $status',
              style: style.caption.copyWith(color: tokens.muted),
            ),
          ),
        ),
      ),
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

class _Tile extends ConsumerWidget {
  const _Tile({
    required this.entry,
    required this.serverUrl,
    required this.showStatus,
    required this.selected,
    required this.selecting,
    required this.onTap,
  });

  final BacklogEntry entry;
  final String? serverUrl;
  final bool showStatus;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toBeat = entry.mainTime;
    final members = ref.watch(spaceMembersProvider);
    return ShelfCover(
      title: entry.title,
      footer: members == null
          ? null
          : MemberProgress(
              entry: entry,
              me: members.me,
              partner: members.partner,
            ),
      selected: selected,
      selectionMode: selecting,
      onTap: onTap,
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
  const _Row({
    required this.entry,
    required this.selected,
    required this.selecting,
    required this.onTap,
  });

  final BacklogEntry entry;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        key: Key('library-row-${entry.id}'),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : null,
          border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
        ),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              if (selecting) ...[
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  key: const Key('row-check'),
                  size: 18,
                  color: selected ? tokens.accent : tokens.muted,
                ),
                const SizedBox(width: 12),
              ],
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
      ),
    );
  }
}

/// What every game of the library can do: a click opens it, or toggles it
/// while selecting; a right click opens the context menu; Enter or Space
/// activates it, Backspace or Delete asks to delete it and the arrow keys move
/// the focus to the neighbouring game.
class _EntryTarget extends ConsumerStatefulWidget {
  const _EntryTarget({required this.entry, required this.builder, super.key});

  final BacklogEntry entry;
  final Widget Function(
    BuildContext context,
    bool selected,
    bool selecting,
    VoidCallback onTap,
  )
  builder;

  @override
  ConsumerState<_EntryTarget> createState() => _EntryTargetState();
}

class _EntryTargetState extends ConsumerState<_EntryTarget> {
  bool _focused = false;

  BacklogEntry get _entry => widget.entry;

  void _activate() {
    if (ref.read(selectionProvider).active) {
      ref.read(selectionProvider.notifier).toggle(_entry.id);
    } else {
      LibraryActionsScope.of(context).openDetails(_entry.id);
    }
  }

  void _requestDelete() {
    final selection = ref.read(selectionProvider);
    final entries =
        ref.read(entriesProvider(ref.read(backlogScopeProvider))).value ??
        const [];
    final targets =
        selection.ids.length > 1 && selection.ids.contains(_entry.id)
        ? [
            for (final entry in entries)
              if (selection.ids.contains(entry.id)) entry,
          ]
        : [_entry];
    LibraryActionsScope.of(context).deleteEntries(targets);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _activate();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _requestDelete();
      return KeyEventResult.handled;
    }
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      _ => null,
    };
    if (direction != null && node.focusInDirection(direction)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<ShelfMenuEntry> _menu(
    LibraryActions actions,
    List<String> statuses,
    List<Category> categories,
    Set<int> assigned,
  ) {
    final selection = ref.read(selectionProvider);
    return [
      ShelfMenuLabel(_entry.title),
      const ShelfMenuDivider(),
      ShelfMenuItem(
        label: 'Open details',
        icon: Icons.open_in_new,
        shortcut: 'Enter',
        onSelected: () => actions.openDetails(_entry.id),
      ),
      ShelfMenuItem(
        label: 'Select',
        icon: Icons.checklist,
        onSelected: () {
          final notifier = ref.read(selectionProvider.notifier);
          if (!selection.active) {
            notifier.start(_entry.id);
          } else if (!selection.ids.contains(_entry.id)) {
            notifier.toggle(_entry.id);
          }
        },
      ),
      ShelfMenuItem(
        label: 'Move to status',
        icon: Icons.swap_horiz,
        submenu: [
          for (final status in statuses)
            ShelfMenuItem(
              label: status,
              onSelected: status == _entry.status
                  ? null
                  : () => actions.moveEntry(_entry, status),
            ),
        ],
      ),
      if (categories.isEmpty)
        const ShelfMenuItem(label: 'Categories', icon: Icons.sell_outlined)
      else
        ShelfMenuItem(
          label: 'Categories',
          icon: Icons.sell_outlined,
          submenu: [
            for (final category in categories)
              ShelfMenuItem(
                label: category.name,
                checked: assigned.contains(category.id),
                keepOpen: true,
                onSelected: () => actions.setCategory(
                  _entry.id,
                  category.id,
                  assigned: !assigned.contains(category.id),
                ),
              ),
          ],
        ),
      const ShelfMenuDivider(),
      ShelfMenuItem(
        label: 'Delete',
        icon: Icons.delete_outline,
        danger: true,
        shortcut: 'Backspace',
        onSelected: _requestDelete,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final (selecting, selected) = ref.watch(
      selectionProvider.select(
        (state) => (state.active, state.ids.contains(_entry.id)),
      ),
    );
    final statuses = ref.watch(
      filterOptionsProvider.select((options) => options.statuses),
    );
    final categories =
        ref.watch(categoriesProvider(ref.watch(backlogScopeProvider))).value ??
        const <Category>[];
    final assigned = {
      for (final category
          in ref
                  .watch(
                    entryCategoriesProvider(ref.watch(backlogScopeProvider)),
                  )
                  .value?[_entry.id] ??
              const <Category>[])
        category.id,
    };
    final actions = LibraryActionsScope.of(context);
    final sortBy = ref.watch(libraryViewProvider.select((v) => v.sortBy));
    final drag = LibraryDragScope.maybeOf(context);
    final canDrag =
        drag != null &&
        !selecting &&
        (sortBy == SortOption.status || sortBy == SortOption.category);
    final face = widget.builder(context, selected, selecting, _activate);

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _onKey,
      child: ContextMenuRegion(
        key: Key('library-tile-${_entry.id}'),
        entries: _menu(actions, statuses, categories, assigned),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShelfRadius.card),
            border: _focused ? Border.all(color: tokens.glow, width: 2) : null,
          ),
          child: canDrag
              ? EntryDragSource(entry: _entry, drag: drag, child: face)
              : face,
        ),
      ),
    );
  }
}
