import 'dart:math';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/backlog_scope.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/library_groups.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/palette_search.dart';
import 'package:backlog_manager/domain/random_pull.dart';
import 'package:backlog_manager/features/library/library_content.dart';
import 'package:backlog_manager/features/library/reveal_entry.dart';
import 'package:backlog_manager/features/random_pull/slot_reel.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The source of the random pull; tests pass a fixed sequence.
final randomProvider = Provider<Random>((ref) => Random());

/// Opens the random pull: one game of the backlog at random.
Future<void> showRandomPullSheet(BuildContext context) {
  return showShelfSheet<void>(context, builder: (_) => const RandomPullSheet());
}

/// The random pull in three steps. First the groups the library is sorted by
/// are listed and the user chooses which of them take part (and whether
/// finished games do); then a slot machine reel spins and stops on a game of
/// the chosen groups at random (so the filters and the search narrow it too),
/// and the result offers "Pull Again", "Change groups" and "Open Details".
/// In the Shared Space the games are those of the space the user owns, and
/// the pull opens the game there. While the result is shown it follows the
/// library: a game that leaves the pool is replaced by another pull.
/// "Pull Again" never gives the same game twice in a row.
class RandomPullSheet extends ConsumerStatefulWidget {
  const RandomPullSheet({super.key});

  @override
  ConsumerState<RandomPullSheet> createState() => _RandomPullSheetState();
}

enum _Stage { choosing, spinning, result }

/// Games on a reel while it spins.
const _reelLength = 28;

class _RandomPullSheetState extends ConsumerState<RandomPullSheet> {
  var _includeFinished = false;
  var _stage = _Stage.choosing;
  final _excluded = <String>{};
  int? _pulled;
  var _pulls = 0;
  List<BacklogEntry> _strip = const [];

  List<LibraryGroup> get _groups =>
      ref.read(libraryContentProvider)?.groups ?? const [];

  List<BacklogEntry> _pool() =>
      pullPool(_groups, excluded: _excluded, includeFinished: _includeFinished);

  void _pick() {
    final pool = _pool();
    final entry = pickRandom(pool, ref.read(randomProvider), exceptId: _pulled);
    _pulled = entry?.id;
    if (entry == null) return;
    _strip = reelStrip(
      pool,
      entry,
      length: _reelLength,
      random: Random(_pulls++),
    );
  }

  void _start() {
    setState(() {
      _pick();
      _stage = _pulled == null ? _Stage.choosing : _Stage.spinning;
    });
  }

  void _replace() => setState(_pick);

  bool get shared => ref.read(backlogScopeProvider) != null;

  void _open(BacklogEntry entry) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    ref.read(revealRequestProvider.notifier).request(entry.id);
    router.go(
      Uri(
        path: shared ? AppRoutes.space : AppRoutes.library,
        queryParameters: {'entry': '${entry.id}'},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryContentProvider);
    final pool = _pool();
    final entry = pool.where((e) => e.id == _pulled).firstOrNull;
    if (_stage == _Stage.result && entry == null && pool.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _replace();
      });
    }

    return ShelfSheet(
      title: 'Random Pull',
      description:
          'One game of your ${shared ? 'Shared Space' : 'library'} at random, '
          'from what your filters show.',
      width: ShelfSheetWidth.compact,
      footer: switch (_stage) {
        _Stage.choosing => _footer([
          ShelfButton(
            key: const Key('random-pull-start'),
            label: 'Pull',
            icon: Icons.casino_outlined,
            kind: ShelfButtonKind.primary,
            onPressed: pool.isEmpty ? null : _start,
          ),
        ]),
        _Stage.spinning => null,
        _Stage.result =>
          entry == null
              ? _footer([_changeGroups()])
              : _footer([
                  _changeGroups(),
                  if (pool.length > 1)
                    ShelfButton(
                      key: const Key('random-pull-again'),
                      label: 'Pull Again',
                      icon: Icons.casino_outlined,
                      onPressed: () => setState(() {
                        _pick();
                        _stage = _Stage.spinning;
                      }),
                    ),
                  ShelfButton(
                    key: const Key('random-pull-open'),
                    label: 'Open Details',
                    kind: ShelfButtonKind.primary,
                    onPressed: () => _open(entry),
                  ),
                ]),
      },
      child: switch (_stage) {
        _Stage.choosing => _Choosing(
          groups: _groups,
          excluded: _excluded,
          includeFinished: _includeFinished,
          poolSize: pool.length,
          onToggleGroup: (key, included) => setState(() {
            if (included) {
              _excluded.remove(key);
            } else {
              _excluded.add(key);
            }
          }),
          onAll: () => setState(_excluded.clear),
          onNone: () => setState(() {
            _excluded
              ..clear()
              ..addAll(_groups.map((group) => group.key));
          }),
          onIncludeFinished: (value) =>
              setState(() => _includeFinished = value),
        ),
        _Stage.spinning => SlotReel(
          key: ValueKey(_pulls),
          strip: _strip,
          onDone: () {
            if (mounted) setState(() => _stage = _Stage.result);
          },
        ),
        _Stage.result => _Result(entry: entry, poolSize: pool.length),
      },
    );
  }

  Widget _changeGroups() => ShelfButton(
    key: const Key('random-pull-change-groups'),
    label: 'Change groups',
    kind: ShelfButtonKind.quiet,
    onPressed: () => setState(() => _stage = _Stage.choosing),
  );

  Widget _footer(List<Widget> buttons) => Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    ),
  );
}

class _Choosing extends StatelessWidget {
  const _Choosing({
    required this.groups,
    required this.excluded,
    required this.includeFinished,
    required this.poolSize,
    required this.onToggleGroup,
    required this.onAll,
    required this.onNone,
    required this.onIncludeFinished,
  });

  final List<LibraryGroup> groups;
  final Set<String> excluded;
  final bool includeFinished;
  final int poolSize;
  final void Function(String key, bool included) onToggleGroup;
  final VoidCallback onAll;
  final VoidCallback onNone;
  final ValueChanged<bool> onIncludeFinished;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Groups that take part',
                style: style.control.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ShelfButton(
              key: const Key('random-pull-groups-all'),
              label: 'All',
              kind: ShelfButtonKind.quiet,
              onPressed: onAll,
            ),
            ShelfButton(
              key: const Key('random-pull-groups-none'),
              label: 'None',
              kind: ShelfButtonKind.quiet,
              onPressed: onNone,
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final group in groups)
          _GroupRow(
            group: group,
            included: !excluded.contains(group.key),
            count: groupPullCount(group, includeFinished: includeFinished),
            onChanged: (included) => onToggleGroup(group.key, included),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Include finished games',
                style: style.caption.copyWith(color: tokens.muted),
              ),
            ),
            ShelfSwitch(
              key: const Key('random-pull-include-finished'),
              value: includeFinished,
              label: 'Include finished games',
              onChanged: onIncludeFinished,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (poolSize == 0)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No game to pull', style: style.section),
              const SizedBox(height: 2),
              Text(
                'No game matches your filters and groups. Clear the filters, '
                'choose more groups or include finished games.',
                style: style.caption.copyWith(color: tokens.muted),
              ),
            ],
          )
        else
          Text(
            poolSize == 1
                ? '1 game to choose from'
                : '$poolSize games to choose from',
            style: style.caption.copyWith(color: tokens.muted),
          ),
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.included,
    required this.count,
    required this.onChanged,
  });

  final LibraryGroup group;
  final bool included;
  final int count;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final color = group.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        key: Key('random-pull-group-${group.key}'),
        children: [
          ShelfCheckbox(
            key: Key('random-pull-group-check-${group.key}'),
            value: included,
            label: group.label,
            onChanged: onChanged,
          ),
          const SizedBox(width: 10),
          if (color != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorFromHex(color),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 9, height: 9),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.control.copyWith(
                color: included ? tokens.foreground : tokens.muted,
              ),
            ),
          ),
          Text(
            count == 1 ? '1 game' : '$count games',
            style: style.caption.copyWith(color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.entry, required this.poolSize});

  final BacklogEntry? entry;
  final int poolSize;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final entry = this.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entry != null)
          _PulledGame(entry: entry)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No game to pull', style: style.section),
                const SizedBox(height: 4),
                Text(
                  'No game matches your filters and groups.',
                  style: style.body.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Text(
          poolSize == 1
              ? '1 game to choose from'
              : '$poolSize games to choose from',
          style: style.caption.copyWith(color: tokens.muted),
        ),
      ],
    );
  }
}

class _PulledGame extends ConsumerWidget {
  const _PulledGame({required this.entry});

  final BacklogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final image = entryImage(
      ref.watch(serverUrlProvider).value,
      entry.imageLink,
    );
    final facts = [...entry.genre, ...entry.platform].join(' · ');
    return Row(
      key: Key('random-pull-game-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 110,
            height: 165,
            child: image == null
                ? ColoredBox(color: tokens.surface2)
                : Image(image: image, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                key: const Key('random-pull-title'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: style.page.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                gameMeta(entry),
                style: style.body.copyWith(color: tokens.text2),
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(facts, style: style.caption.copyWith(color: tokens.muted)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
