import 'dart:math' as math;

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/format.dart';
import 'package:backlog_manager/domain/home_logic.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/common/entries_gate.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _shelfLength = 12;

/// How many achievements of a Steam game are still locked, or null when the
/// server cannot tell; the hero card then leaves the number out.
final achievementsToGoProvider = FutureProvider.family<int?, int>((
  ref,
  steamAppId,
) async {
  ref.watch(sessionGenerationProvider);
  try {
    final progress = await ref
        .watch(backlogApiProvider)
        .achievements(steamAppId);
    return progress.total - progress.unlocked;
  } on Object {
    return null;
  }
});

String _library(Map<String, String> query) =>
    Uri(path: AppRoutes.library, queryParameters: query).toString();

/// The home screen: four stat tiles, the game to continue and shelves with the
/// games to start next and those finished lately.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _reportedCount;

  void _report(String? counts) {
    if (counts == _reportedCount) return;
    _reportedCount = counts;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(shellStatusProvider.notifier);
      if (counts == null) {
        status.clear();
      } else {
        status.update(counts: counts);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider(null));
    final list = entries.value;
    _report(
      list == null
          ? null
          : '${list.length} ${list.length == 1 ? 'game' : 'games'}',
    );

    return KeyedSubtree(
      key: const Key('page-home'),
      child: EntriesGate(
        builder: (context, list) =>
            list.isEmpty ? const _EmptyBacklog() : _Content(entries: list),
      ),
    );
  }
}

class _EmptyBacklog extends StatelessWidget {
  const _EmptyBacklog();

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
            'Add a game by hand or bring your Steam library over.',
            style: style.caption.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShelfButton(
                label: 'Add a game',
                kind: ShelfButtonKind.primary,
                onPressed: () => context.go(AppRoutes.creationTool),
              ),
              const SizedBox(width: 10),
              ShelfButton(
                label: 'Sync Steam',
                onPressed: () => context.go(AppRoutes.steam),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.entries});

  final List<BacklogEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = homeStats(entries, now: DateTime.now());
    final playing = continuePlaying(entries);
    final next = upNext(entries).take(_shelfLength).toList();
    final done = recentlyCompleted(entries).take(_shelfLength).toList();
    final serverUrl = ref.watch(serverUrlProvider).value;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatTiles(stats: stats),
          if (playing != null) ...[
            const SizedBox(height: 22),
            _Hero(
              key: ValueKey(playing.id),
              entry: playing,
              serverUrl: serverUrl,
            ),
          ],
          if (next.isNotEmpty)
            _Shelf(
              shelfKey: 'up-next',
              title: 'Up next',
              subtitle: 'Short games first',
              status: 'Not Started',
              entries: next,
              serverUrl: serverUrl,
              meta: (entry) => entry.mainTime == null
                  ? null
                  : '${formatHours(entry.mainTime!)} h to beat',
            ),
          if (done.isNotEmpty)
            _Shelf(
              shelfKey: 'recently-completed',
              title: 'Recently completed',
              status: 'Completed',
              entries: done,
              serverUrl: serverUrl,
              meta: (entry) =>
                  entry.reviewStars == null || entry.reviewStars == 0
                  ? null
                  : '${entry.reviewStars}/10',
            ),
        ],
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'In backlog',
            value: formatCount(stats.inBacklog),
            unit: 'games',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatTile(
            label: 'Time to beat',
            value: formatCount(stats.timeToBeat.round()),
            unit: 'h',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatTile(
            label: 'Playing now',
            value: formatCount(stats.playingNow),
            unit: 'games',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatTile(
            label: 'Completed this year',
            value: formatCount(stats.completedThisYear),
            unit: 'games',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(ShelfRadius.card),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: style.label.copyWith(color: tokens.muted)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: style.page),
                const SizedBox(width: 6),
                Text(unit, style: style.caption.copyWith(color: tokens.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends ConsumerStatefulWidget {
  const _Hero({required this.entry, required this.serverUrl, super.key});

  final BacklogEntry entry;
  final String? serverUrl;

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero> {
  bool _busy = false;

  Future<void> _complete() async {
    setState(() => _busy = true);
    final failure = await ref
        .read(entriesProvider(null).notifier)
        .moveToStatus(widget.entry.id, 'Completed');
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) showShelfToast(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final entry = widget.entry;
    final played = entry.playtime ?? 0;
    final toBeat = entry.mainTime;
    final steamAppId = entry.steamAppId;
    final toGo = steamAppId == null
        ? null
        : ref.watch(achievementsToGoProvider(steamAppId)).value;

    final parts = [
      toBeat == null
          ? '${formatHours(played)} h played'
          : '${formatHours(played)} of ${formatHours(toBeat)} h',
      if (toGo != null && toGo > 0)
        '$toGo ${toGo == 1 ? 'achievement' : 'achievements'} to go',
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(ShelfRadius.panel),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.borderSubtle),
          borderRadius: BorderRadius.circular(ShelfRadius.panel),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _OrbitPainter(tokens))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: ShelfCover(
                      title: entry.title,
                      image: entryImage(widget.serverUrl, entry.imageLink),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTINUE PLAYING',
                          style: style.eyebrow.copyWith(color: tokens.accent),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.title,
                          style: style.hero,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          parts.join(' · '),
                          style: style.body.copyWith(color: tokens.text2),
                        ),
                        if (toBeat != null && toBeat > 0) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 360,
                            child: ShelfProgressBar(value: played / toBeat),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            ShelfButton(
                              label: 'Open details',
                              kind: ShelfButtonKind.primary,
                              onPressed: () => context.go(
                                _library({'entry': '${entry.id}'}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ShelfButton(
                              label: 'Mark as completed',
                              busy: _busy,
                              onPressed: _complete,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two orbit rings and two small planets at the right edge of the hero card.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.tokens);

  final ShelfTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width - 70, size.height / 2);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tokens.orbit;
    canvas.drawCircle(center, 120, ring);
    canvas.drawCircle(center, 190, ring);
    canvas.drawCircle(
      center + Offset(120 * math.cos(-0.6), 120 * math.sin(-0.6)),
      7,
      Paint()..color = tokens.accentA,
    );
    canvas.drawCircle(
      center + Offset(190 * math.cos(2.4), 190 * math.sin(2.4)),
      4,
      Paint()..color = tokens.accentB,
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.tokens != tokens;
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.shelfKey,
    required this.title,
    required this.status,
    required this.entries,
    required this.serverUrl,
    required this.meta,
    this.subtitle,
  });

  final String shelfKey;
  final String title;
  final String? subtitle;
  final String status;
  final List<BacklogEntry> entries;
  final String? serverUrl;
  final String? Function(BacklogEntry entry) meta;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        key: Key('shelf-$shelfKey'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(title, style: style.section),
              if (subtitle != null) ...[
                const SizedBox(width: 10),
                Text(
                  subtitle!,
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ],
              const Spacer(),
              ShelfButton(
                key: Key('see-all-$shelfKey'),
                label: 'See all',
                kind: ShelfButtonKind.quiet,
                onPressed: () => context.go(_library({'status': status})),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ShelfRow(
            extraHeight: 28,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ShelfCover(
                title: entry.title,
                image: entryImage(serverUrl, entry.imageLink),
                meta: meta(entry),
                onTap: () => context.go(_library({'entry': '${entry.id}'})),
              );
            },
          ),
        ],
      ),
    );
  }
}
