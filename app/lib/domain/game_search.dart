import 'package:backlog_manager/domain/format.dart';

/// A game the search found, with what HowLongToBeat and IGDB know about it.
class GameSearchResult {
  const GameSearchResult({
    required this.id,
    required this.title,
    required this.genres,
    required this.platforms,
    required this.mainStory,
    required this.mainStoryWithExtras,
    required this.completionist,
    this.imageUrl,
    this.steamAppId,
    this.description,
    this.publisher,
    this.trailerUrl,
  });

  final int id;
  final String title;
  final String? imageUrl;
  final int? steamAppId;
  final List<String> genres;
  final List<String> platforms;
  final double mainStory;
  final double mainStoryWithExtras;
  final double completionist;
  final String? description;
  final String? publisher;
  final String? trailerUrl;

  /// "22 / 48 / 95 h", with a dash for a time that is not known.
  String get timesLabel {
    String part(double hours) => hours > 0 ? formatHours(hours) : '–';
    return '${part(mainStory)} / ${part(mainStoryWithExtras)} / '
        '${part(completionist)} h';
  }
}

/// A game found on SteamGridDB, whose covers can be listed.
class SteamGridDbMatch {
  const SteamGridDbMatch({required this.id, required this.name});

  final int id;
  final String name;
}

/// The path of the creation tool.
const _creationTool = '/creation-tool';

/// How much of the description is carried to the creation tool.
const _descriptionLimit = 500;

String _location(Map<String, String> query) {
  return Uri(path: _creationTool, queryParameters: query).toString();
}

String _hours(double hours) => hours == hours.roundToDouble()
    ? hours.toInt().toString()
    : hours.toString();

/// Where "Continue in Creation Tool" goes: the creation tool with the chosen
/// result in the address. Inside a Shared Space [inSpace] names it as the
/// target.
String creationToolLocation(GameSearchResult result, {bool inSpace = false}) {
  final description = result.description ?? '';
  return _location({
    if (inSpace) 'target': 'space',
    'title': result.title,
    'imageUrl': result.imageUrl ?? '',
    'steamAppId': '${result.steamAppId ?? ''}',
    'genres': result.genres.join(', '),
    'platforms': result.platforms.join(', '),
    'mainStory': _hours(result.mainStory),
    'mainStoryWithExtras': _hours(result.mainStoryWithExtras),
    'completionist': _hours(result.completionist),
    'description': description.length > _descriptionLimit
        ? description.substring(0, _descriptionLimit)
        : description,
    'publisher': result.publisher ?? '',
    'trailerUrl': result.trailerUrl ?? '',
  });
}

/// Where "Create '<title>' as custom game" goes.
String customGameLocation(String title, {bool inSpace = false}) {
  return _location({
    if (inSpace) 'target': 'space',
    'title': title,
    'custom': '1',
  });
}

/// How many games the batch mode of the creation tool takes at once; each
/// title is one search.
const maxBatchTitles = 50;

/// The titles of a batch, one per line: trimmed, empty lines left out, each
/// title once whatever its case, at most [maxBatchTitles].
List<String> batchTitles(String text) {
  final titles = <String>[];
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final title = line.trim();
    if (title.isEmpty) continue;
    if (titles.any((known) => known.toLowerCase() == title.toLowerCase())) {
      continue;
    }
    titles.add(title);
    if (titles.length == maxBatchTitles) break;
  }
  return titles;
}

/// Where the batch mode of "Search for a game" goes: the creation tool with
/// the [titles], one per line. Inside a Shared Space [inSpace] names it as
/// the target of all of them.
String batchCreationLocation(List<String> titles, {bool inSpace = false}) {
  return _location({
    if (inSpace) 'target': 'space',
    'batch': titles.join('\n'),
  });
}

/// The ids of the results that only the deeper search found, to mark them.
Set<int> deeperIds({
  required List<GameSearchResult> normal,
  required List<GameSearchResult> deep,
}) {
  final known = {for (final result in normal) result.id};
  return {
    for (final result in deep)
      if (!known.contains(result.id)) result.id,
  };
}

/// What replaces the data of an entry when the chosen result is the right
/// game: title, cover, description, publisher, trailer and the three times, the genres
/// only when the result has some, and the Steam App ID goes.
class WrongGameChanges {
  const WrongGameChanges({
    required this.title,
    required this.imageLink,
    required this.description,
    required this.publisher,
    required this.trailerLink,
    required this.mainTime,
    required this.mainPlusExtraTime,
    required this.completionTime,
    this.genre,
    this.clearSteamAppId = true,
  });

  final String title;
  final List<String>? genre;
  final String imageLink;
  final String? description;
  final String? publisher;
  final String? trailerLink;
  final double mainTime;
  final double mainPlusExtraTime;
  final double completionTime;
  final bool clearSteamAppId;
}

WrongGameChanges wrongGameChanges(GameSearchResult result) {
  return WrongGameChanges(
    title: result.title,
    genre: result.genres.isEmpty ? null : result.genres,
    imageLink: result.imageUrl ?? '',
    description: result.description,
    publisher: result.publisher,
    trailerLink: result.trailerUrl,
    mainTime: result.mainStory,
    mainPlusExtraTime: result.mainStoryWithExtras,
    completionTime: result.completionist,
  );
}
