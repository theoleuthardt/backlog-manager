import 'dart:math';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/palette_search.dart';
import 'package:backlog_manager/domain/random_pull.dart';
import 'package:backlog_manager/features/library/library_content.dart';
import 'package:backlog_manager/features/library/reveal_entry.dart';
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

/// Pulls one game at random from the games the library shows (so the filters
/// and the search narrow it), by default only from the games still to play.
/// "Pull Again" never gives the same game twice in a row, and "Open Details"
/// takes the game to the library.
class RandomPullSheet extends ConsumerStatefulWidget {
  const RandomPullSheet({super.key});

  @override
  ConsumerState<RandomPullSheet> createState() => _RandomPullSheetState();
}

class _RandomPullSheetState extends ConsumerState<RandomPullSheet> {
  var _includeFinished = false;
  int? _pulled;

  List<BacklogEntry> _pool() {
    final groups = ref.read(libraryContentProvider)?.groups ?? const [];
    return pullCandidates([
      for (final group in groups) ...group.entries,
    ], includeFinished: _includeFinished);
  }

  void _pull() {
    final entry = pickRandom(
      _pool(),
      ref.read(randomProvider),
      exceptId: _pulled,
    );
    setState(() => _pulled = entry?.id);
  }

  @override
  void initState() {
    super.initState();
    final entry = pickRandom(_pool(), ref.read(randomProvider));
    _pulled = entry?.id;
  }

  void _open(BacklogEntry entry) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    ref.read(revealRequestProvider.notifier).request(entry.id);
    router.go(
      Uri(
        path: AppRoutes.library,
        queryParameters: {'entry': '${entry.id}'},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final pool = _pool();
    final entry = pool.where((e) => e.id == _pulled).firstOrNull;
    final count = pool.length;

    return ShelfSheet(
      title: 'Random Pull',
      description:
          'One game of your library at random, from what your filters show.',
      width: ShelfSheetWidth.compact,
      footer: entry == null
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (count > 1) ...[
                  ShelfButton(
                    key: const Key('random-pull-again'),
                    label: 'Pull Again',
                    icon: Icons.casino_outlined,
                    onPressed: _pull,
                  ),
                  const SizedBox(width: 8),
                ],
                ShelfButton(
                  key: const Key('random-pull-open'),
                  label: 'Open Details',
                  kind: ShelfButtonKind.primary,
                  onPressed: () => _open(entry),
                ),
              ],
            ),
      child: Column(
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
                    'No game matches your filters. Clear them or include '
                    'finished games.',
                    style: style.body.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  count == 1
                      ? '1 game to choose from'
                      : '$count games to choose from',
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ),
              Text(
                'Include finished games',
                style: style.caption.copyWith(color: tokens.muted),
              ),
              const SizedBox(width: 8),
              ShelfSwitch(
                key: const Key('random-pull-include-finished'),
                value: _includeFinished,
                label: 'Include finished games',
                onChanged: (value) {
                  setState(() => _includeFinished = value);
                  _pull();
                },
              ),
            ],
          ),
        ],
      ),
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
