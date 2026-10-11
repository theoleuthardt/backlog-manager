import 'dart:convert';

import 'package:backlog_manager/domain/library_groups.dart';

/// The library's [groups] in the order the user arranged them. Groups the
/// saved [order] does not know yet (a new status or category) follow the known
/// ones in their default order; saved keys without a group are ignored.
List<LibraryGroup> applyGroupOrder(
  List<LibraryGroup> groups,
  List<String> order,
) {
  if (order.isEmpty) return groups;
  final rank = {for (final (index, key) in order.indexed) key: index};
  final known = [
    for (final group in groups)
      if (rank.containsKey(group.key)) group,
  ]..sort((a, b) => rank[a.key]!.compareTo(rank[b.key]!));
  return [
    ...known,
    for (final group in groups)
      if (!rank.containsKey(group.key)) group,
  ];
}

/// [order] with [from] taken out and put where [onto] was, like dragging an
/// item in a reorderable list: dropping on a later group moves it behind that
/// group, dropping on an earlier one moves it in front.
List<String> moveGroup(
  List<String> order, {
  required String from,
  required String onto,
}) {
  final fromIndex = order.indexOf(from);
  final ontoIndex = order.indexOf(onto);
  if (fromIndex == -1 || ontoIndex == -1 || fromIndex == ontoIndex) {
    return order;
  }
  return [...order]
    ..removeAt(fromIndex)
    ..insert(ontoIndex, from);
}

/// [order] with [key] moved [offset] places; stays put at either end.
List<String> moveGroupBy(List<String> order, String key, int offset) {
  final index = order.indexOf(key);
  final target = index + offset;
  if (index == -1 || target < 0 || target >= order.length) return order;
  return moveGroup(order, from: key, onto: order[target]);
}

String encodeGroupOrder(List<String> order) => jsonEncode(order);

/// The saved order, or an empty one when [source] is missing or not a list;
/// entries that are not strings are dropped.
List<String> decodeGroupOrder(String? source) {
  if (source == null) return const [];
  try {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is String) item,
    ];
  } on FormatException {
    return const [];
  }
}
