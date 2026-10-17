/// The platforms the sheet "Manage Platforms" offers besides those of the
/// backlog, spelled like the hints of the app ("PC, PS5, Xbox").
const commonPlatforms = [
  'PC',
  'PS5',
  'PS4',
  'Xbox Series X|S',
  'Xbox One',
  'Switch',
  'Steam Deck',
  'Mobile',
];

bool _same(String a, String b) => a.toLowerCase() == b.toLowerCase();

/// The platforms to choose from: the [selected] ones first in their order,
/// then the others of the backlog ([inBacklog]) and the common ones, each
/// platform once whatever its case.
List<String> platformChoices({
  required List<String> selected,
  required List<String> inBacklog,
}) {
  final choices = <String>[];
  for (final name in [...selected, ...inBacklog, ...commonPlatforms]) {
    if (!choices.any((known) => _same(known, name))) choices.add(name);
  }
  return choices;
}

/// [selected] with [name] added at the end, or without it when it is there.
List<String> togglePlatform(List<String> selected, String name) {
  if (selected.any((known) => _same(known, name))) {
    return [
      for (final known in selected)
        if (!_same(known, name)) known,
    ];
  }
  return [...selected, name];
}

/// [selected] with the typed [name] added: trimmed, and not when it is empty,
/// already there or holds a comma (which would split it in the list).
List<String> addPlatform(List<String> selected, String typed) {
  final name = typed.trim();
  if (name.isEmpty ||
      name.contains(',') ||
      selected.any((known) => _same(known, name))) {
    return selected;
  }
  return [...selected, name];
}

/// The platforms after the user's choice in the sheet, applied to [current],
/// the platforms the game has by then: what the user added ([chosen] but not
/// [initial]) is added and what they removed is removed, everything else stays,
/// also a change that came in while the sheet was open.
List<String> applyPlatformChanges({
  required List<String> current,
  required List<String> initial,
  required List<String> chosen,
}) {
  bool has(List<String> list, String name) =>
      list.any((known) => _same(known, name));
  var result = current;
  for (final name in chosen) {
    if (!has(initial, name) && !has(result, name)) result = [...result, name];
  }
  for (final name in initial) {
    if (!has(chosen, name)) {
      result = [
        for (final known in result)
          if (!_same(known, name)) known,
      ];
    }
  }
  return result;
}
