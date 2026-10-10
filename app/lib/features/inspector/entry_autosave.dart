import 'dart:async';

import 'package:backlog_manager/domain/entry_changes.dart';
import 'package:flutter/foundation.dart';

enum SaveState { idle, saving, saved, error }

/// Saves the edits of the inspector without a button: 800 ms after the last
/// change the fields that differ from the stored entry ([pending]) are sent
/// through [save]. Edits that arrive while a request runs are saved by the
/// next one, because [pending] is read again against the refreshed entry when
/// the request is done. A failed save is reported to [onError] and stays
/// "not saved" until the next edit. [flush] sends what is pending when the
/// inspector closes.
class EntryAutosave {
  EntryAutosave({
    required this.pending,
    required this.save,
    required this.onError,
    this.delay = const Duration(milliseconds: 800),
  });

  final EntryFormChanges Function() pending;
  final Future<void> Function(EntryFormChanges changes) save;
  final void Function(Object error) onError;
  final Duration delay;

  final state = ValueNotifier<SaveState>(SaveState.idle);

  Timer? _timer;
  bool _saving = false;
  bool _disposed = false;

  /// Call after every edit, and whenever the stored entry changed.
  void changed() {
    if (_disposed) return;
    _timer?.cancel();
    if (pending().isEmpty) return;
    _timer = Timer(delay, _run);
  }

  Future<void> _run() async {
    final changes = pending();
    if (_disposed || _saving || changes.isEmpty) return;
    _saving = true;
    state.value = SaveState.saving;
    try {
      await save(changes);
      if (_disposed) return;
      state.value = SaveState.saved;
    } on Object catch (error) {
      if (_disposed) return;
      state.value = SaveState.error;
      onError(error);
      return;
    } finally {
      _saving = false;
    }
    changed();
  }

  /// Sends the pending changes now, unless a request is running (it ends by
  /// looking at what is pending again).
  void flush() {
    _timer?.cancel();
    final changes = pending();
    if (_saving || changes.isEmpty) return;
    unawaited(save(changes).catchError((Object _) {}));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    state.dispose();
  }
}
