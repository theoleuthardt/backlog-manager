import 'dart:math';

import 'package:backlog_manager/domain/library_groups.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/status_names.dart';

const _finishedStatuses = {'Completed', 'Dropped'};

/// The games a random pull can choose from among [entries]: the games the
/// user owns, without the completed and dropped ones unless [includeFinished]
/// is set. A game the user does not own (a wishlist game) is never pulled;
/// both the owned flag and the status "Not Owned" count, since an older entry
/// can carry one without the other.
List<BacklogEntry> pullCandidates(
  List<BacklogEntry> entries, {
  required bool includeFinished,
}) {
  return [
    for (final entry in entries)
      if (entry.owned &&
          entry.status != notOwnedStatus &&
          (includeFinished || !_finishedStatuses.contains(entry.status)))
        entry,
  ];
}

/// One game of [pool] at random, or null for an empty pool. The game with
/// [exceptId] (the one just pulled) is left out when another one is there.
BacklogEntry? pickRandom(
  List<BacklogEntry> pool,
  Random random, {
  int? exceptId,
}) {
  if (pool.isEmpty) return null;
  final others = [
    for (final entry in pool)
      if (entry.id != exceptId) entry,
  ];
  final from = others.isEmpty ? pool : others;
  return from[random.nextInt(from.length)];
}

/// The games of the groups of the library that take part in a random pull:
/// every group except those whose key is in [excluded], filtered by
/// [pullCandidates].
List<BacklogEntry> pullPool(
  List<LibraryGroup> groups, {
  required Set<String> excluded,
  required bool includeFinished,
}) {
  return pullCandidates([
    for (final group in groups)
      if (!excluded.contains(group.key)) ...group.entries,
  ], includeFinished: includeFinished);
}

/// How many games of [group] a random pull can choose from.
int groupPullCount(LibraryGroup group, {required bool includeFinished}) {
  return pullCandidates(group.entries, includeFinished: includeFinished).length;
}

/// The games of a slot machine reel and the one it stops on.
class ReelStrip {
  const ReelStrip({required this.games, required this.stopIndex});

  final List<BacklogEntry> games;

  /// The position in [games] of the pulled game.
  final int stopIndex;
}

/// The games a slot machine reel shows while it spins: every game of [pool]
/// once, shuffled with [random], ending on [picked]. A pool that gives fewer
/// than [minLength] games is repeated in front by whole rounds (every game
/// once per round, shuffled each time), so every game is on the reel equally
/// often, and [trailing] more games follow the picked one, so the reel looks
/// as if it could have stopped on any game. Never the same game twice in a
/// row (unless the pool has only one).
ReelStrip reelStrip(
  List<BacklogEntry> pool,
  BacklogEntry picked, {
  required int minLength,
  required int trailing,
  required Random random,
}) {
  if (pool.isEmpty) return ReelStrip(games: [picked], stopIndex: 0);
  final backwards = <BacklogEntry>[
    picked,
    ...[
      for (final entry in pool)
        if (entry.id != picked.id) entry,
    ]..shuffle(random),
  ];
  while (backwards.length < minLength) {
    backwards.addAll(_round(pool, random, backwards.last.id));
  }
  final games = backwards.reversed.toList();
  final stopIndex = games.length - 1;
  final after = <BacklogEntry>[];
  while (after.length < trailing) {
    after.addAll(
      _round(pool, random, after.isEmpty ? picked.id : after.last.id),
    );
  }
  return ReelStrip(
    games: [...games, ...after.take(trailing)],
    stopIndex: stopIndex,
  );
}

/// Every game of [pool] once in random order, not starting with the game
/// with [previousId] (when the pool has another).
List<BacklogEntry> _round(
  List<BacklogEntry> pool,
  Random random,
  int previousId,
) {
  final round = [...pool]..shuffle(random);
  if (round.length > 1 && round.first.id == previousId) {
    final swap = 1 + random.nextInt(round.length - 1);
    final first = round.first;
    round[0] = round[swap];
    round[swap] = first;
  }
  return round;
}

/// How strong the sparks at the pointer of the slot machine reel are, from 0
/// to 1, at [progress] (0 to 1) of a spin that moves the reel by [rows] rows
/// in [seconds] with an ease-out cubic curve: they follow the speed of the reel, so they
/// are full while it is fast, die down as it slows and are gone before it
/// stops.
double reelSparks(
  double progress, {
  required int rows,
  required double seconds,
}) {
  final rowsPerSecond = rows / seconds * 3 * pow(1 - progress.clamp(0, 1), 2);
  return ((rowsPerSecond - 2) / 6).clamp(0, 1).toDouble();
}
