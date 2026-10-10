import 'package:backlog_manager/domain/diff_fields.dart';
import 'package:backlog_manager/domain/models.dart';

/// The title as the duplicate check compares it: without case and without
/// outer or repeated spaces.
String normalizedTitle(String title) =>
    title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Entries that are the same game: they share the title, the Steam App ID or
/// both. [entries] are in the order of their ids.
class DuplicateGroup {
  const DuplicateGroup({
    required this.entries,
    required this.sharedTitle,
    required this.sharedSteamAppId,
  });

  final List<BacklogEntry> entries;
  final bool sharedTitle;
  final bool sharedSteamAppId;

  /// The title of the first entry.
  String get title => entries.first.title;

  /// What the entries of the group have in common.
  String get reason {
    if (sharedTitle && sharedSteamAppId) return 'Same title and Steam App ID';
    return sharedTitle ? 'Same title' : 'Same Steam App ID';
  }
}

/// The games that are in the backlog more than once, by title or by Steam App
/// ID (entries linked by either end up in one group), ordered by title.
List<DuplicateGroup> findDuplicateGroups(List<BacklogEntry> entries) {
  final parent = List<int>.generate(entries.length, (i) => i);
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  void union(int a, int b) => parent[find(a)] = find(b);

  final firstByTitle = <String, int>{};
  final firstByApp = <int, int>{};
  for (var i = 0; i < entries.length; i++) {
    final title = normalizedTitle(entries[i].title);
    final byTitle = firstByTitle.putIfAbsent(title, () => i);
    if (byTitle != i) union(i, byTitle);
    final appId = entries[i].steamAppId;
    if (appId != null) {
      final byApp = firstByApp.putIfAbsent(appId, () => i);
      if (byApp != i) union(i, byApp);
    }
  }

  final members = <int, List<BacklogEntry>>{};
  for (var i = 0; i < entries.length; i++) {
    members.putIfAbsent(find(i), () => []).add(entries[i]);
  }

  final groups = <DuplicateGroup>[];
  for (final group in members.values) {
    if (group.length < 2) continue;
    group.sort((a, b) => a.id.compareTo(b.id));
    final titles = {for (final e in group) normalizedTitle(e.title)};
    final appIds = [
      for (final e in group)
        if (e.steamAppId != null) e.steamAppId!,
    ];
    groups.add(
      DuplicateGroup(
        entries: group,
        sharedTitle: titles.length < group.length,
        sharedSteamAppId: appIds.toSet().length < appIds.length,
      ),
    );
  }
  groups.sort(
    (a, b) => normalizedTitle(a.title).compareTo(normalizedTitle(b.title)),
  );
  return groups;
}

String duplicatesHeading(int groups, int entries) {
  if (groups == 0) return 'No duplicates found';
  final games = groups == 1 ? 'game is' : 'games are';
  return '$groups $games in your backlog more than once ($entries entries)';
}

DiffableFields _fieldsOf(BacklogEntry entry) {
  return DiffableFields(
    genre: entry.genre,
    platform: entry.platform,
    status: entry.status,
    owned: entry.owned,
    playtime: entry.playtime,
    reviewStars: entry.reviewStars,
    note: entry.note,
  );
}

/// What [other] has different from [kept], with [kept] as the old side.
List<FieldDiffEntry> diffAgainst(BacklogEntry kept, BacklogEntry other) {
  return computeFieldDiffs(_fieldsOf(kept), _fieldsOf(other));
}
