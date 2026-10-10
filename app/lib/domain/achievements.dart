/// One Steam achievement of a game.
class GameAchievement {
  const GameAchievement({
    required this.apiname,
    required this.displayName,
    required this.achieved,
    required this.hidden,
    this.description,
    this.icon,
  });

  final String apiname;
  final String displayName;
  final String? description;
  final String? icon;
  final bool achieved;
  final bool hidden;

  /// The line under the name: the description, "Hidden achievement" for a
  /// hidden one that is not unlocked yet and has no description, else null.
  String? get detail {
    final text = description;
    if (text != null && text.isNotEmpty) return text;
    return hidden && !achieved ? 'Hidden achievement' : null;
  }
}

/// How far the account is through the achievements of a game.
class GameAchievements {
  const GameAchievements({
    required this.unlocked,
    required this.total,
    required this.items,
  });

  final int unlocked;
  final int total;
  final List<GameAchievement> items;

  /// A game without achievements shows nothing.
  bool get isEmpty => total == 0;

  int get percent => total == 0 ? 0 : (unlocked / total * 100).round();
}
