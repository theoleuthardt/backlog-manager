/// Splits a comma separated form value into trimmed, non-empty items.
List<String> splitList(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
