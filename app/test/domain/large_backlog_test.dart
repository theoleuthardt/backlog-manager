import 'package:backlog_manager/domain/filter_entries.dart';
import 'package:backlog_manager/domain/group_entries.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:flutter_test/flutter_test.dart';

const statuses = ['Not Started', 'Playing', 'Completed', 'Dropped'];
const entryCount = 10000;
const timeBudget = Duration(seconds: 3);

List<BacklogEntry> largeBacklog() {
  return List.generate(
    entryCount,
    (id) => BacklogEntry(
      id: id,
      title: 'Game ${(id * 7919) % entryCount}',
      genre: const ['Action'],
      platform: const ['PC'],
      status: statuses[id % statuses.length],
      owned: id % 2 == 0,
      interest: id % 5,
    ),
  );
}

Duration timed(void Function() run) {
  final watch = Stopwatch()..start();
  run();
  return watch.elapsed;
}

void main() {
  final entries = largeBacklog();

  test('filters 10k entries within the time budget', () {
    var result = <BacklogEntry>[];
    final elapsed = timed(() {
      result = filterEntries(entries, const EntryFilters(search: 'game 12'));
    });

    expect(result, isNotEmpty);
    expect(elapsed, lessThan(timeBudget));
  });

  test('sorts 10k entries within the time budget', () {
    var result = <BacklogEntry>[];
    final elapsed = timed(() {
      result = sortEntries(
        entries,
        const SortConfig(
          sortBy: SortOption.status,
          direction: SortDirection.asc,
          statusOrder: statuses,
        ),
      );
    });

    expect(result, hasLength(entryCount));
    expect(elapsed, lessThan(timeBudget));
  });

  test('groups 10k entries by status within the time budget', () {
    var groups = <StatusGroup>[];
    final elapsed = timed(() {
      groups = groupEntriesByStatus(entries, statuses);
    });

    expect(groups.fold<int>(0, (sum, g) => sum + g.entries.length), entryCount);
    expect(elapsed, lessThan(timeBudget));
  });
}
