import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How big the covers of the library and the Shared Space are: the narrowest
/// a cover may get before a row holds one less. On a phone in portrait that
/// is three, two or one cover per row.
enum CoverSize {
  small('small', 'Small', 100),
  medium('medium', 'Medium', 150),
  large('large', 'Large', 200);

  const CoverSize(this.value, this.label, this.minWidth);

  /// The identifier kept on the device.
  final String value;
  final String label;
  final double minWidth;
}

const _coverSizeKey = 'blm-cover-size';

/// Keeps the cover size on the device. A store that cannot be read or
/// written is ignored.
abstract interface class CoverSizeStore {
  Future<String?> read();

  Future<void> write(String value);
}

class PreferencesCoverSizeStore implements CoverSizeStore {
  const PreferencesCoverSizeStore();

  @override
  Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_coverSizeKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_coverSizeKey, value);
    } on Object {
      return;
    }
  }
}

final coverSizeStoreProvider = Provider<CoverSizeStore>(
  (ref) => const PreferencesCoverSizeStore(),
);

/// The cover size of this device, [CoverSize.medium] until another one is
/// chosen; a choice made before the stored one is read wins.
class CoverSizeNotifier extends Notifier<CoverSize> {
  var _chosen = false;

  @override
  CoverSize build() {
    unawaited(_load(ref.read(coverSizeStoreProvider)));
    return CoverSize.medium;
  }

  Future<void> _load(CoverSizeStore store) async {
    final stored = await store.read();
    if (!ref.mounted || _chosen) return;
    for (final size in CoverSize.values) {
      if (size.value == stored) state = size;
    }
  }

  void select(CoverSize size) {
    _chosen = true;
    state = size;
    unawaited(ref.read(coverSizeStoreProvider).write(size.value));
  }
}

final coverSizeProvider = NotifierProvider<CoverSizeNotifier, CoverSize>(
  CoverSizeNotifier.new,
);
