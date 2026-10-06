/// A game of the backlog as the app uses it; the generated API model is
/// mapped to this at the boundary.
class BacklogEntry {
  const BacklogEntry({
    required this.id,
    required this.title,
    this.imageLink = '',
    this.imageAlt = '',
    this.genre = const [],
    this.platform = const [],
    this.status = 'Not Started',
    this.owned = false,
    this.interest = 0,
    this.reviewStars,
    this.review,
    this.note,
    this.description,
    this.trailerLink,
    this.mainTime,
    this.mainPlusExtraTime,
    this.completionTime,
    this.playtime,
    this.partnerPlaytime,
    this.inSharedSpace = false,
    this.steamAppId,
    this.completedAt,
  });

  final int id;
  final String title;
  final String imageLink;
  final String imageAlt;
  final List<String> genre;
  final List<String> platform;
  final String status;
  final bool owned;
  final int interest;
  final int? reviewStars;
  final String? review;
  final String? note;
  final String? description;
  final String? trailerLink;
  final double? mainTime;
  final double? mainPlusExtraTime;
  final double? completionTime;
  final double? playtime;
  final double? partnerPlaytime;
  final bool inSharedSpace;
  final int? steamAppId;
  final DateTime? completedAt;
}

/// A user-defined category entries can be assigned to.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.color,
    this.description,
  });

  final int id;
  final String name;
  final String color;
  final String? description;
}
