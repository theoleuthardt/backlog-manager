const _accentGroups = {
  'a': 'àáâãäåāăą',
  'c': 'çćĉċč',
  'd': 'ďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħ',
  'i': 'ìíîïĩīĭįı',
  'j': 'ĵ',
  'k': 'ķ',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉ',
  'o': 'òóôõöøōŏő',
  'r': 'ŕŗř',
  's': 'śŝşš',
  't': 'ţťŧ',
  'u': 'ùúûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

final _baseLetters = {
  for (final group in _accentGroups.entries)
    for (final letter in group.value.split('')) letter: group.key,
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
};

String _foldAccents(String value) {
  return value
      .toLowerCase()
      .split('')
      .map((letter) => _baseLetters[letter] ?? letter)
      .join();
}

/// Compares two strings by their letters only, ignoring case and accents, like
/// `localeCompare` with the sensitivity `base`. Latin letters are folded, other
/// scripts compare by code unit.
int compareBase(String a, String b) =>
    _foldAccents(a).compareTo(_foldAccents(b));

/// Orders two strings like the locale-aware comparison of the web client for
/// the app's data: letters first (accents and case ignored, so "Ärger" sorts
/// with "A"), then an unaccented spelling before an accented one, then the
/// lower-case spelling before the upper-case one.
int compareText(String a, String b) {
  final byLetters = compareBase(a, b);
  if (byLetters != 0) return byLetters;
  final byAccents = a.toLowerCase().compareTo(b.toLowerCase());
  return byAccents != 0 ? byAccents : b.compareTo(a);
}

/// A sorted copy of [items] that keeps the input order of items that compare
/// equal, like `Array.prototype.sort` does; `List.sort` makes no such promise.
List<T> stableSorted<T>(List<T> items, int Function(T a, T b) compare) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final result = compare(a.$2, b.$2);
    return result != 0 ? result : a.$1.compareTo(b.$1);
  });
  return [for (final item in indexed) item.$2];
}
