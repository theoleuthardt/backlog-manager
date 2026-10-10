import 'package:backlog_manager/domain/models.dart';

/// The group a pointer at height [dy] is over, given the tops of the group
/// headers that are on screen ([headerTops], by group index): the last header
/// above the pointer. Above the first header on screen it is the group before
/// it, which extends up past the viewport; above the very first group it is
/// nothing.
int? groupIndexAt(double dy, Map<int, double> headerTops) {
  if (headerTops.isEmpty) return null;
  final indexes = headerTops.keys.toList()..sort();
  int? over;
  for (final index in indexes) {
    if (headerTops[index]! <= dy) over = index;
  }
  if (over != null) return over;
  final before = indexes.first - 1;
  return before >= 0 ? before : null;
}

/// What dropping a game on a category group changes: the category to add and
/// the one to remove.
class CategoryMove {
  const CategoryMove({this.add, this.remove});

  final Category? add;
  final Category? remove;
}

/// The change for dropping a game with the [assigned] categories on [target]:
/// the target is added unless the game has it, and the first category goes.
/// Null when the target already is the first category.
CategoryMove? categoryMove({
  required List<Category> assigned,
  required Category target,
}) {
  final source = assigned.firstOrNull;
  if (source?.id == target.id) return null;
  return CategoryMove(
    add: assigned.any((category) => category.id == target.id) ? null : target,
    remove: source,
  );
}

/// How fast to scroll, in pixels per tick, while a game is dragged with the
/// pointer at [pointer] in a viewport from [top] to [bottom]: negative near
/// the top, positive near the bottom, faster the closer to the edge and
/// capped at the edge itself.
double edgeScrollVelocity(
  double pointer, {
  required double top,
  required double bottom,
  double edge = 72,
  double maxSpeed = 18,
}) {
  final fromTop = pointer - top;
  final fromBottom = bottom - pointer;
  if (fromTop < edge) {
    return -maxSpeed * (1 - fromTop.clamp(0, edge) / edge);
  }
  if (fromBottom < edge) {
    return maxSpeed * (1 - fromBottom.clamp(0, edge) / edge);
  }
  return 0;
}
