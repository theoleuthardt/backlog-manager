/// Input cleanup before a request is sent, the same rules the backend
/// applies (`backend/src/backlog_manager_backend/sanitize.py`).
///
/// Invisible formatting characters (bidi overrides and isolates,
/// directional marks, zero-width spaces, word joiners, byte order marks)
/// and control characters other than tab and line breaks are removed and
/// the edges are trimmed. Punctuation is never touched, the zero-width
/// joiner and non-joiner stay for emoji sequences, and passwords are kept
/// exactly as typed. Unicode normalization (NFC) is left to the backend,
/// since Dart has no built-in normalizer.
library;

const _invisible = {
  0x061C,
  0x200B,
  0x200E,
  0x200F,
  0x202A,
  0x202B,
  0x202C,
  0x202D,
  0x202E,
  0x2060,
  0x2066,
  0x2067,
  0x2068,
  0x2069,
  0xFEFF,
};

const _keptControls = {0x09, 0x0A, 0x0D};

bool _isRemoved(int rune) {
  if (_invisible.contains(rune)) return true;
  if (_keptControls.contains(rune)) return false;
  return rune < 0x20 || (rune >= 0x7F && rune <= 0x9F);
}

/// [value] without invisible and control characters, trimmed.
String sanitizeText(String value) =>
    String.fromCharCodes(value.runes.where((rune) => !_isRemoved(rune))).trim();

/// Every string in the JSON [value] passed through [sanitizeText]; object
/// keys and the value of any `password` key are left as they are.
Object? sanitizeJson(Object? value) => switch (value) {
  final String text => sanitizeText(text),
  final List<Object?> items => [for (final item in items) sanitizeJson(item)],
  final Map<String, Object?> map => {
    for (final MapEntry(:key, value: item) in map.entries)
      key: key == 'password' ? item : sanitizeJson(item),
  },
  _ => value,
};

final _username = RegExp(r'^[A-Za-z0-9_.-]{3,32}$');

/// Whether [name] is a username the server lets be set: 3 to 32 letters,
/// digits, `_`, `-` or `.`.
bool isValidUsername(String name) => _username.hasMatch(name);

final _emailShape = RegExp(r'^[^\s@]+@[^\s@]+$');

/// Whether [email] has the shape of an address: one `@` with something on
/// both sides and no whitespace. Looser than the server's rule for setting
/// an address, so every existing account can still sign in.
bool looksLikeEmail(String email) => _emailShape.hasMatch(email);
