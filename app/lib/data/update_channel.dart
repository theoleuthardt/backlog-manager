import 'dart:async';

import 'package:backlog_manager/domain/app_update.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'blm-update-channel';

/// Keeps the update channel on the device: it belongs to this install, not to
/// the account. A store that cannot be read or written is ignored.
abstract interface class UpdateChannelStore {
  Future<UpdateChannel?> read();

  Future<void> write(UpdateChannel channel);
}

class PreferencesUpdateChannelStore implements UpdateChannelStore {
  const PreferencesUpdateChannelStore();

  @override
  Future<UpdateChannel?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return UpdateChannel.fromName(prefs.getString(_storageKey));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(UpdateChannel channel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, channel.name);
    } on Object {
      return;
    }
  }
}

final updateChannelStoreProvider = Provider<UpdateChannelStore>(
  (ref) => const PreferencesUpdateChannelStore(),
);

/// The channel the app updates from. It is [UpdateChannel.stable] until the
/// user chooses; Preview also takes the pre-releases.
class UpdateChannelNotifier extends Notifier<UpdateChannel> {
  var _chosen = false;

  @override
  UpdateChannel build() {
    unawaited(_load(ref.read(updateChannelStoreProvider)));
    return UpdateChannel.stable;
  }

  Future<void> _load(UpdateChannelStore store) async {
    try {
      final stored = await store.read();
      if (ref.mounted && !_chosen && stored != null) state = stored;
    } on Object {
      return;
    }
  }

  void select(UpdateChannel channel) {
    _chosen = true;
    state = channel;
    unawaited(ref.read(updateChannelStoreProvider).write(channel));
  }
}

final updateChannelProvider =
    NotifierProvider<UpdateChannelNotifier, UpdateChannel>(
      UpdateChannelNotifier.new,
    );
