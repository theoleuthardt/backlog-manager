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

/// The games a slot machine reel shows while it spins: [length] games of
/// [pool] drawn with [random], never the same game twice in a row (unless the
/// pool has one), and ending on [picked]; it is drawn backwards from it.
List<BacklogEntry> reelStrip(
  List<BacklogEntry> pool,
  BacklogEntry picked, {
  required int length,
  required Random random,
}) {
  final backwards = <BacklogEntry>[picked];
  for (var i = 1; i < length; i++) {
    backwards.add(pickRandom(pool, random, exceptId: backwards.last.id)!);
  }
  return backwards.reversed.toList();
}
