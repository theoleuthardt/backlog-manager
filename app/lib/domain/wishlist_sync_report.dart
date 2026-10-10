/// One game the automatic Steam wishlist sync added to or removed from the
/// backlog.
class WishlistChange {
  const WishlistChange({
    required this.steamAppId,
    required this.title,
    this.imageLink,
  });

  final int steamAppId;
  final String title;
  final String? imageLink;
}

/// A line of the diff: `-` for a removed game, `+` for an added one.
class WishlistDiffRow {
  const WishlistDiffRow(this.sign, this.change);

  final String sign;
  final WishlistChange change;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// What the automatic wishlist sync changed since the user last closed the
/// report; [since] is the time of the first change.
class WishlistSyncReport {
  const WishlistSyncReport({
    this.since,
    this.added = const [],
    this.removed = const [],
  });

  final DateTime? since;
  final List<WishlistChange> added;
  final List<WishlistChange> removed;

  bool get hasChanges => added.isNotEmpty || removed.isNotEmpty;

  /// The removed games first, then the added ones, like a diff.
  List<WishlistDiffRow> get diffRows => [
    for (final change in removed) WishlistDiffRow('-', change),
    for (final change in added) WishlistDiffRow('+', change),
  ];

  /// "2 games added, 1 game removed since 9 Oct 2026".
  String get summary {
    final parts = [
      if (added.isNotEmpty) _count(added.length, 'added'),
      if (removed.isNotEmpty) _count(removed.length, 'removed'),
    ].join(', ');
    final date = since?.toUtc();
    if (date == null) return parts;
    return '$parts since ${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  static String _count(int amount, String verb) =>
      '$amount game${amount == 1 ? '' : 's'} $verb';
}
