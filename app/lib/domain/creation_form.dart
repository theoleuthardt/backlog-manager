import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/domain/split_list.dart';

/// What the add-a-game sheet put into the address of the creation tool: a
/// search result, or a custom game with only a title.
class CreationPrefill {
  const CreationPrefill({
    required this.custom,
    this.title = '',
    this.imageUrl = '',
    this.description = '',
    this.publisher = '',
    this.trailerUrl = '',
    this.genres = '',
    this.platforms = '',
    this.mainStory = 0,
    this.mainStoryWithExtras = 0,
    this.completionist = 0,
    this.targetsSpace = false,
  });

  factory CreationPrefill.fromQuery(Map<String, String> query) {
    double hours(String key) => double.tryParse(query[key] ?? '') ?? 0;
    return CreationPrefill(
      custom: query['custom'] == '1',
      title: query['title'] ?? '',
      imageUrl: query['imageUrl'] ?? '',
      description: query['description'] ?? '',
      publisher: query['publisher'] ?? '',
      trailerUrl: query['trailerUrl'] ?? '',
      genres: query['genres'] ?? '',
      platforms: query['platforms'] ?? '',
      mainStory: hours('mainStory'),
      mainStoryWithExtras: hours('mainStoryWithExtras'),
      completionist: hours('completionist'),
      targetsSpace: query['target'] == 'space',
    );
  }

  /// The prefill of [result] for a game of a batch, like the one the address
  /// of [creationToolLocation] carries but with the whole description.
  factory CreationPrefill.fromResult(GameSearchResult result) =>
      CreationPrefill(
        custom: false,
        title: result.title,
        imageUrl: result.imageUrl ?? '',
        description: result.description ?? '',
        publisher: result.publisher ?? '',
        trailerUrl: result.trailerUrl ?? '',
        genres: result.genres.join(', '),
        platforms: result.platforms.join(', '),
        mainStory: result.mainStory,
        mainStoryWithExtras: result.mainStoryWithExtras,
        completionist: result.completionist,
      );

  final bool custom;
  final String title;
  final String imageUrl;
  final String description;
  final String publisher;
  final String trailerUrl;
  final String genres;
  final String platforms;
  final double mainStory;
  final double mainStoryWithExtras;
  final double completionist;
  final bool targetsSpace;

  List<String> get platformOptions => splitList(platforms);

  /// PC (Microsoft Windows) when the game is offered for it, else the first
  /// platform, else nothing.
  String get defaultPlatform {
    final options = platformOptions;
    return options.firstWhere(
      (option) => option == 'PC (Microsoft Windows)',
      orElse: () => options.firstOrNull ?? '',
    );
  }

  bool get hasHltbData =>
      mainStory > 0 || mainStoryWithExtras > 0 || completionist > 0;

  /// The search found no cover or no beat times.
  bool get hasMissingData => imageUrl.isEmpty || !hasHltbData;

  String get missingDataMessage {
    return '${imageUrl.isEmpty ? 'No image found. ' : ''}'
        '${hasHltbData ? '' : 'No game beat times found. '}'
        'Consider searching for the game again in the searchbar to get '
        'complete data.';
  }
}

/// Where the creation tool adds the game: the personal backlog, the Shared
/// Space, or both (two entries, one in each).
enum CreationTarget {
  personal,
  space,
  both;

  /// The backlogs to create the entry in (null is the personal one); always
  /// the personal one without an active space ([spaceId] null).
  List<int?> scopes(int? spaceId) => switch (this) {
    _ when spaceId == null => const [null],
    CreationTarget.personal => const [null],
    CreationTarget.space => [spaceId],
    CreationTarget.both => [null, spaceId],
  };
}

/// The values of the creation form as the user typed them.
class CreationInput {
  const CreationInput({
    required this.title,
    required this.genre,
    required this.platform,
    required this.status,
    required this.owned,
    required this.interest,
    required this.playtime,
    required this.steamAppId,
    required this.imageUrl,
    this.publisher = '',
    required this.mainStory,
    required this.mainStoryWithExtras,
    required this.completionist,
    required this.reviewStars,
    required this.review,
    required this.note,
  });

  final String title;
  final String genre;
  final String platform;
  final String status;
  final bool owned;
  final int interest;
  final String playtime;
  final String steamAppId;
  final String imageUrl;
  final String publisher;
  final String mainStory;
  final String mainStoryWithExtras;
  final String completionist;
  final int reviewStars;
  final String review;
  final String note;
}

/// The message of the first thing missing from the form, in the words of the
/// web client, or null when the entry can be created.
String? validateCreation(CreationInput input) {
  if (input.title.trim().isEmpty) return 'Please enter a title';
  if (splitList(input.genre).isEmpty) return 'Please enter at least one genre';
  if (splitList(input.platform).isEmpty) return 'Please select a platform';
  if (input.status.isEmpty) return 'Please select a status';
  return null;
}

/// The Steam App ID typed or looked up: a positive whole number, else null.
int? resolvedSteamAppId(String text) {
  final value = int.tryParse(text.trim());
  return value != null && value > 0 ? value : null;
}

/// The playtime of the form: what the user typed once they touched the field,
/// else the playtime of the Steam account for the App ID when there is one.
String effectivePlaytime({
  required bool touched,
  required String typed,
  required double? fromSteam,
}) {
  if (touched || fromSteam == null) return typed;
  return fromSteam == fromSteam.roundToDouble()
      ? fromSteam.toInt().toString()
      : fromSteam.toString();
}

/// An entry ready to be created.
class NewEntry {
  const NewEntry({
    required this.title,
    required this.genre,
    required this.platform,
    required this.status,
    required this.owned,
    required this.interest,
    required this.playtime,
    this.steamAppId,
    this.imageLink,
    this.description,
    this.publisher,
    this.trailerLink,
    this.mainTime,
    this.mainPlusExtraTime,
    this.completionTime,
    this.reviewStars,
    this.review,
    this.note,
  });

  final String title;
  final List<String> genre;
  final List<String> platform;
  final String status;
  final bool owned;
  final int interest;
  final double playtime;
  final int? steamAppId;
  final String? imageLink;
  final String? description;
  final String? publisher;
  final String? trailerLink;
  final double? mainTime;
  final double? mainPlusExtraTime;
  final double? completionTime;
  final int? reviewStars;
  final String? review;
  final String? note;

  /// This entry without its Steam App ID, for a backlog that already holds
  /// that App ID.
  NewEntry withoutSteamAppId() => NewEntry(
    title: title,
    genre: genre,
    platform: platform,
    status: status,
    owned: owned,
    interest: interest,
    playtime: playtime,
    imageLink: imageLink,
    description: description,
    publisher: publisher,
    trailerLink: trailerLink,
    mainTime: mainTime,
    mainPlusExtraTime: mainPlusExtraTime,
    completionTime: completionTime,
    reviewStars: reviewStars,
    review: review,
    note: note,
  );
}

String? _blankToNull(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _hoursAboveZero(String text) {
  final value = double.tryParse(text.trim());
  return value != null && value > 0 ? value : null;
}

/// The entry the form describes; description and trailer come from the
/// search. Beat times of zero, an empty cover and an empty review are left
/// out.
NewEntry buildNewEntry(CreationInput input, CreationPrefill prefill) {
  return NewEntry(
    title: input.title.trim(),
    genre: splitList(input.genre),
    platform: splitList(input.platform),
    status: input.status,
    owned: input.owned,
    interest: input.interest,
    playtime: double.tryParse(input.playtime.trim()) ?? 0,
    steamAppId: resolvedSteamAppId(input.steamAppId),
    imageLink: _blankToNull(input.imageUrl),
    description: _blankToNull(prefill.description),
    publisher: _blankToNull(input.publisher),
    trailerLink: _blankToNull(prefill.trailerUrl),
    mainTime: _hoursAboveZero(input.mainStory),
    mainPlusExtraTime: _hoursAboveZero(input.mainStoryWithExtras),
    completionTime: _hoursAboveZero(input.completionist),
    reviewStars: input.reviewStars > 0 ? input.reviewStars : null,
    review: input.review.isEmpty ? null : input.review,
    note: input.note.isEmpty ? null : input.note,
  );
}
