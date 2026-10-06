final _httpUrl = RegExp(r'^(https?):[/\\]*(.*)$', caseSensitive: false);

/// Whether [value] is an absolute http or https URL, the only kinds that are
/// safe to open from a link the backend or a third party supplied. Like the
/// WHATWG parser of the web client it takes the text after the scheme as the
/// host even without the two slashes (`https:example.com`), and it rejects an
/// empty host.
bool isHttpUrl(String value) {
  final match = _httpUrl.firstMatch(value);
  if (match == null) return false;
  final uri = Uri.tryParse('${match[1]!.toLowerCase()}://${match[2]}');
  return uri != null && uri.host.isNotEmpty;
}
