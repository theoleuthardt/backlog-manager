import 'dart:math';

import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/status_names.dart';

const _finishedStatuses = {'Completed', 'Dropped'};

/// The games a random pull can choose from among [entries]: the games the
/// user owns, without the completed and dropped ones unless [includeFinished]
/// is set. A game the user does not own (a wishlist game) is never pulled.
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
