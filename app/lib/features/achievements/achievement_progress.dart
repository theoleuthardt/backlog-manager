import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/achievements.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The achievement progress of a Steam game: "Achievements  3/15 (20%)", a
/// progress bar and "Show all achievements", which opens the list. It shows
/// nothing for a game without a Steam App ID or achievements and when the
/// request fails.
class AchievementProgressSection extends ConsumerWidget {
  const AchievementProgressSection({required this.steamAppId, super.key});

  final int? steamAppId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appId = steamAppId;
    if (appId == null) return const SizedBox.shrink();
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final achievements = ref.watch(achievementsProvider(appId));

    return achievements.when(
      loading: () => Row(
        key: const Key('achievements-loading'),
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.accent,
            ),
          ),
          const SizedBox(width: 10),
          Text('Loading achievements...', style: style.caption),
        ],
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return Column(
          key: const Key('achievements'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 16,
                  color: tokens.text2,
                ),
                const SizedBox(width: 6),
                Text('Achievements', style: style.control),
                const Spacer(),
                Text(
                  '${data.unlocked}/${data.total} (${data.percent}%)',
                  key: const Key('achievements-count'),
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ShelfProgressBar(value: data.percent / 100),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                key: const Key('show-achievements'),
                behavior: HitTestBehavior.opaque,
                onTap: () => showShelfSheet<void>(
                  context,
                  builder: (_) => AchievementsSheet(achievements: data),
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Show all achievements',
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Every achievement of a game with its icon, name and description; the ones
/// not unlocked yet are dimmed.
class AchievementsSheet extends ConsumerWidget {
  const AchievementsSheet({required this.achievements, super.key});

  final GameAchievements achievements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverUrl = ref.watch(serverUrlProvider).value;
    return ShelfSheet(
      title: 'Achievements (${achievements.unlocked}/${achievements.total})',
      width: ShelfSheetWidth.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in achievements.items)
            _AchievementRow(item: item, serverUrl: serverUrl),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.item, required this.serverUrl});

  final GameAchievement item;
  final String? serverUrl;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final image = entryImage(serverUrl, item.icon ?? '');
    final detail = item.detail;
    return Opacity(
      opacity: item.achieved ? 1 : 0.4,
      child: Padding(
        key: Key('achievement-${item.apiname}'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 32,
                height: 32,
                child: image == null
                    ? ColoredBox(color: tokens.surface3)
                    : Image(image: image, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: style.control,
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      overflow: TextOverflow.ellipsis,
                      style: style.caption.copyWith(
                        color: tokens.muted,
                        fontStyle: item.description?.isNotEmpty ?? false
                            ? null
                            : FontStyle.italic,
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
