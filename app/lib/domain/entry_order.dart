import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/text_order.dart';

/// How the games inside one group of the library are ordered, chosen in the
/// header of the group; each order has the direction that makes sense for it
/// (the newest, the most interesting, the most played, the shortest and the
/// best rated first). Games without the value come last, ties by title.
enum EntryOrder {
  title('Title'),
  added('Date added'),
  interest('Interest'),
  playtime('Playtime'),
  timeToBeat('Time to beat'),
  reviewStars('Review stars');

  const EntryOrder(this.label);

  final String label;
}

/// The value [order] compares, turned so that a smaller value comes first,
/// or null when the game has none.
num? _key(BacklogEntry entry, EntryOrder order) {
  switch (order) {
    case EntryOrder.title:
      return 0;
    case EntryOrder.added:
      final added = entry.createdAt;
      return added == null ? null : -added.millisecondsSinceEpoch;
    case EntryOrder.interest:
      return -entry.interest;
    case EntryOrder.playtime:
      final playtime = entry.playtime;
      return playtime == null || playtime <= 0 ? null : -playtime;
    case EntryOrder.timeToBeat:
      return entry.timeToBeat;
    case EntryOrder.reviewStars:
      final stars = entry.reviewStars;
      return stars == null || stars == 0 ? null : -stars;
  }
}

/// A copy of [entries] in [order].
List<BacklogEntry> orderEntries(List<BacklogEntry> entries, EntryOrder order) {
  return stableSorted(entries, (a, b) {
    final keyA = _key(a, order);
    final keyB = _key(b, order);
    if (keyA == null && keyB != null) return 1;
    if (keyA != null && keyB == null) return -1;
    if (keyA != null && keyB != null) {
      final result = keyA.compareTo(keyB);
      if (result != 0) return result;
    }
    return compareText(a.title, b.title);
  });
}
