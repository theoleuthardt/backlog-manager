/// A published release of the app that is newer than the installed one.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.pageUrl,
    this.notes = '',
  });

  /// `1.2.3`, without the `v` of the tag.
  final String version;
  final Uri pageUrl;
  final String notes;
}

final _plainVersion = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');

/// `[major, minor, patch]` of `1.2.3` or `v1.2.3`, null for anything else
/// (pre-release suffixes and build numbers included).
List<int>? parseVersion(String text) {
  final match = _plainVersion.firstMatch(text.trim());
  if (match == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

/// Whether [candidate] is a greater version than [than]; false when either is
/// not a plain `X.Y.Z`.
bool isNewerVersion(String candidate, {required String than}) {
  final left = parseVersion(candidate);
  final right = parseVersion(than);
  if (left == null || right == null) return false;
  for (var i = 0; i < 3; i++) {
    if (left[i] != right[i]) return left[i] > right[i];
  }
  return false;
}

/// The release described by one GitHub release JSON object, or null for a
/// draft, a pre-release, a tag that is not a plain version and a page that is
/// not on github.com (the link is opened in the browser).
AppRelease? appReleaseFromJson(Map<String, dynamic> json) {
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final tag = json['tag_name'];
  final page = json['html_url'];
  if (tag is! String || page is! String) return null;
  final version = parseVersion(tag);
  final uri = Uri.tryParse(page);
  if (version == null ||
      uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'github.com') {
    return null;
  }
  final body = json['body'];
  return AppRelease(
    version: version.join('.'),
    pageUrl: uri,
    notes: body is String ? body.trim() : '',
  );
}
