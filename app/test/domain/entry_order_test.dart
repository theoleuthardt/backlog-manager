import 'package:backlog_manager/domain/entry_order.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

BacklogEntry game(
  int id,
  String title, {
  int interest = 0,
  double? playtime,
  double? mainTime,
  int? reviewStars,
  DateTime? createdAt,
}) => BacklogEntry(
  id: id,
  title: title,
  interest: interest,
  playtime: playtime,
  mainTime: mainTime,
  reviewStars: reviewStars,
  createdAt: createdAt,
);

List<String> titles(List<BacklogEntry> entries) => [
  for (final entry in entries) entry.title,
];

void main() {
  final day = DateTime.utc(2026, 10, 1);

  test('title orders alphabetically', () {
    expect(
      titles(
        orderEntries([game(1, 'Celeste'), game(2, 'Hades')], EntryOrder.title),
      ),
      ['Celeste', 'Hades'],
    );
  });

  test('date added puts the newest first, games without a date last', () {
    final entries = [
      game(1, 'Old', createdAt: day),
      game(2, 'Unknown'),
      game(3, 'New', createdAt: day.add(const Duration(days: 3))),
    ];

    expect(titles(orderEntries(entries, EntryOrder.added)), [
      'New',
      'Old',
      'Unknown',
    ]);
  });

  test('interest puts the highest first, ties by title', () {
    final entries = [
      game(1, 'B', interest: 7),
      game(2, 'A', interest: 7),
      game(3, 'C', interest: 9),
    ];

    expect(titles(orderEntries(entries, EntryOrder.interest)), ['C', 'A', 'B']);
  });

  test('playtime puts the most played first, unplayed last', () {
    final entries = [
      game(1, 'None'),
      game(2, 'Some', playtime: 4),
      game(3, 'Lots', playtime: 40),
    ];

    expect(titles(orderEntries(entries, EntryOrder.playtime)), [
      'Lots',
      'Some',
      'None',
    ]);
  });

  test('time to beat puts the shortest first, unknown last', () {
    final entries = [
      game(1, 'Long', mainTime: 60),
      game(2, 'Unknown'),
      game(3, 'Short', mainTime: 5),
    ];

    expect(titles(orderEntries(entries, EntryOrder.timeToBeat)), [
      'Short',
      'Long',
      'Unknown',
    ]);
  });

  test('review stars put the best first, unrated last', () {
    final entries = [
      game(1, 'Unrated'),
      game(2, 'Good', reviewStars: 4),
      game(3, 'Best', reviewStars: 5),
    ];

    expect(titles(orderEntries(entries, EntryOrder.reviewStars)), [
      'Best',
      'Good',
      'Unrated',
    ]);
  });

  test('leaves the list it gets as it is', () {
    final entries = [game(1, 'Hades'), game(2, 'Celeste')];

    orderEntries(entries, EntryOrder.title);

    expect(titles(entries), ['Hades', 'Celeste']);
  });
}
