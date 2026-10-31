/// What a new version of the app changed, shown once after an update
/// (`WhatsNewPrompt`), from the notes of its GitHub release.
library;

import 'package:backlog_manager/domain/app_update.dart';

final _changesHeading = RegExp(r"^#{1,6}\s*What's Changed\s*$");
final _heading = RegExp(r'^#{1,6}\s');
final _bullet = RegExp(r'^[*-]\s+(.*)$');
final _author = RegExp(r'\s+by\s+@[\w-]+(\s+in\s+\S+)?\s*$');
final _commitType = RegExp(r'^[a-z]+(\([^)]*\))?!?:\s*');

/// The changes of a release in plain words: the bullets of its "What's
/// Changed" section (one per pull request), without the author and the link
/// GitHub adds and without the conventional-commit type, starting with a
/// capital letter. Empty for notes without that section.
List<String> releaseChanges(String notes) {
  final changes = <String>[];
  var inSection = false;
  for (final raw in notes.split('\n')) {
    final line = raw.trim();
    if (_changesHeading.hasMatch(line)) {
      inSection = true;
      continue;
    }
    if (!inSection) continue;
    if (_heading.hasMatch(line)) break;
    final bullet = _bullet.firstMatch(line);
    if (bullet == null) continue;
    final text = bullet
        .group(1)!
        .replaceFirst(_author, '')
        .replaceFirst(_commitType, '')
        .trim();
    if (text.isEmpty) continue;
    changes.add(text[0].toUpperCase() + text.substring(1));
  }
  return changes;
}

/// Whether the changes of the [installed] version are still to be shown: only
/// after an update from the [lastSeen] version, not again for the same
/// version or after a downgrade. Nothing was seen yet on a first install,
/// which shows nothing, and on an install from before this feature, which
/// was [inUseBefore] (signed in from its stored session) and shows the
/// changes of the version it was updated to.
bool shouldShowWhatsNew({
  required String installed,
  required String? lastSeen,
  bool inUseBefore = false,
}) =>
    lastSeen == null ? inUseBefore : isNewerVersion(installed, than: lastSeen);
