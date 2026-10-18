import 'package:backlog_manager/domain/safe_url.dart';

/// The longest name a mod can have, as the server allows.
const maxModNameLength = 120;

/// A mod of a game: its name and, when there is one, the page it comes from.
class EntryMod {
  const EntryMod({required this.id, required this.name, this.url});

  final int id;
  final String name;
  final String? url;
}

/// The message of what is wrong with the name or the link of a mod, or null
/// when it can be saved. A blank link is fine, any other has to be http(s).
String? validateMod(String name, String url) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Enter the name of the mod';
  if (trimmed.length > maxModNameLength) {
    return 'The name can have up to $maxModNameLength characters';
  }
  final link = modLink(url);
  if (link != null && !isHttpUrl(link)) {
    return 'The link must start with http:// or https://';
  }
  return null;
}

/// The link as it is saved: trimmed, or null when it is blank.
String? modLink(String url) {
  final trimmed = url.trim();
  return trimmed.isEmpty ? null : trimmed;
}
