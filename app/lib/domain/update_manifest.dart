/// One installer of a release that the app can apply in place.
class UpdatePayload {
  const UpdatePayload({
    required this.url,
    required this.sha256,
    required this.signature,
    required this.size,
  });

  final Uri url;

  /// Lower-case hex SHA-256 of the file.
  final String sha256;

  /// Base64 Ed25519 signature of [updateMessage].
  final String signature;
  final int size;
}

/// What a release publishes for in-place updates (`app-update.json`): the
/// version, its notes and page, and one payload per `{os}-{arch}-{format}`.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.pageUrl,
    required this.payloads,
    this.notes = '',
  });

  final String version;
  final Uri pageUrl;
  final String notes;
  final Map<String, UpdatePayload> payloads;
}

final _plainVersion = RegExp(r'^\d+\.\d+\.\d+$');
final _sha256Hex = RegExp(r'^[0-9a-f]{64}$');

bool _isGithubHttps(Uri? uri) =>
    uri != null && uri.scheme == 'https' && uri.host == 'github.com';

/// The manifest in [json], or null when it is not one. A payload that is not
/// well formed (an address that is not an https github.com one, a hash that is
/// not 64 hex digits, no signature) is left out, so the install stays
/// notify-only instead of acting on it.
UpdateManifest? parseUpdateManifest(Object? json) {
  if (json is! Map) return null;
  final version = json['version'];
  final page = json['page_url'];
  if (version is! String || !_plainVersion.hasMatch(version)) return null;
  final pageUrl = page is String ? Uri.tryParse(page) : null;
  if (!_isGithubHttps(pageUrl)) return null;

  final payloads = <String, UpdatePayload>{};
  final raw = json['payloads'];
  if (raw is Map) {
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) continue;
      final url = value['url'];
      final sha256 = value['sha256'];
      final signature = value['signature'];
      final size = value['size'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (!_isGithubHttps(uri) ||
          sha256 is! String ||
          !_sha256Hex.hasMatch(sha256) ||
          signature is! String ||
          signature.isEmpty ||
          size is! int) {
        continue;
      }
      payloads[key] = UpdatePayload(
        url: uri!,
        sha256: sha256,
        signature: signature,
        size: size,
      );
    }
  }
  final notes = json['notes'];
  return UpdateManifest(
    version: version,
    pageUrl: pageUrl!,
    notes: notes is String ? notes.trim() : '',
    payloads: payloads,
  );
}

/// The text that is signed for one payload: it names the version, the
/// platform key and the hash, so a signature is good for one file only.
String updateMessage({
  required String version,
  required String key,
  required String sha256,
}) => 'blm-update-v1:$version:$key:$sha256';
