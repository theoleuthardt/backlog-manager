import 'dart:async';

import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/domain/group_order.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the order the user gave the library's groups on the device. A store
/// that cannot be read or written is ignored.
abstract interface class GroupOrderStore {
  Future<List<String>> read();

  Future<void> write(List<String> order);
}

const _storageKey = 'blm-group-order';

class PreferencesGroupOrderStore implements GroupOrderStore {
  const PreferencesGroupOrderStore();

  @override
  Future<List<String>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decodeGroupOrder(prefs.getString(_storageKey));
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> write(List<String> order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (order.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, encodeGroupOrder(order));
      }
    } on Object {
      return;
    }
  }
}

final groupOrderStoreProvider = Provider<GroupOrderStore>(
  (ref) => const PreferencesGroupOrderStore(),
);

/// The keys of the groups in the order the user arranged them; empty while
/// the groups keep their default order. Group keys carry their sort option, so
/// one list serves every sort. The order follows the account: the one stored
/// there replaces the one of the device, and an account without one takes it
/// over from the device, which keeps the order of an earlier version. The
/// device keeps a copy for the start and a failed save changes nothing.
class GroupOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    unawaited(_load(ref.read(groupOrderStoreProvider)));
    ref.listen(sessionUserProvider, (_, user) {
      if (user != null) _fromAccount(user.groupOrder);
    });
    return const [];
  }

  Future<void> _load(GroupOrderStore store) async {
    final stored = await store.read();
    if (!ref.mounted || stored.isEmpty) return;
    if (state.isEmpty) {
      state = stored;
      return;
    }
    state = [
      ...state,
      for (final key in stored)
        if (!state.contains(key)) key,
    ];
    unawaited(store.write(state));
  }

  void _fromAccount(List<String> order) {
    if (order.isEmpty) {
      if (state.isNotEmpty) unawaited(_save());
      return;
    }
    if (listEquals(order, state)) return;
    state = order;
    unawaited(ref.read(groupOrderStoreProvider).write(order));
  }

  Future<void> _save() async {
    if (ref.read(sessionUserProvider) == null) return;
    try {
      await ref.read(userApiProvider).update(UserUpdate(groupOrder: state));
    } on Object {
      return;
    }
  }

  /// Saves [arranged], the order of the groups on screen, in front of the
  /// saved keys of groups that are not on screen now.
  void arrange(List<String> arranged) {
    state = [
      ...arranged,
      for (final key in state)
        if (!arranged.contains(key)) key,
    ];
    unawaited(ref.read(groupOrderStoreProvider).write(state));
    unawaited(_save());
  }
}

final groupOrderProvider = NotifierProvider<GroupOrderNotifier, List<String>>(
  GroupOrderNotifier.new,
);
