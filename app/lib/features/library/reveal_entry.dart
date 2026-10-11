import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The game the library is pointing at after a search or a click on a game
/// of the home page; its tile draws an outline while this is set.
class RevealedEntry {
  const RevealedEntry(this.id);

  final int id;
}

/// How long the outline of the revealed game stays.
const revealDuration = Duration(milliseconds: 2200);

class RevealedEntryNotifier extends Notifier<RevealedEntry?> {
  Timer? _timer;

  @override
  RevealedEntry? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void reveal(int id) {
    _timer?.cancel();
    final next = RevealedEntry(id);
    state = next;
    _timer = Timer(revealDuration, () {
      if (ref.mounted && identical(state, next)) state = null;
    });
  }
}

final revealedEntryProvider =
    NotifierProvider<RevealedEntryNotifier, RevealedEntry?>(
      RevealedEntryNotifier.new,
    );

/// A request to point at a game even though the address does not change
/// (the palette opening a game that is already the open one); the nonce makes
/// every request a new value.
class RevealRequest {
  const RevealRequest(this.id, this.nonce);

  final int id;
  final int nonce;
}

class RevealRequestNotifier extends Notifier<RevealRequest?> {
  var _count = 0;

  @override
  RevealRequest? build() => null;

  void request(int id) => state = RevealRequest(id, ++_count);
}

final revealRequestProvider =
    NotifierProvider<RevealRequestNotifier, RevealRequest?>(
      RevealRequestNotifier.new,
    );
