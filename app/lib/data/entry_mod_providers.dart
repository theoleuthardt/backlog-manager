import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/domain/entry_mod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which mod list: the game and the backlog it is in (null for the personal
/// one, else the Shared Space).
typedef ModsScope = ({int entryId, int? spaceId});

/// The mods of one game; dropped when the session changes so the next user
/// never sees them.
final entryModsProvider = FutureProvider.family<List<EntryMod>, ModsScope>((
  ref,
  scope,
) {
  ref.watch(sessionGenerationProvider);
  return ref.watch(backlogApiProvider).entryMods(scope.entryId, scope.spaceId);
});

/// Adds, changes and removes the mods of one game; the list is read again
/// after every change.
class EntryModActions {
  EntryModActions(this._ref, this._scope);

  final Ref _ref;
  final ModsScope _scope;

  Future<void> add(String name, String? url) async {
    await _ref
        .read(backlogApiProvider)
        .addEntryMod(_scope.entryId, name, url, _scope.spaceId);
    _ref.invalidate(entryModsProvider(_scope));
  }

  Future<void> update(int modId, String name, String? url) async {
    await _ref
        .read(backlogApiProvider)
        .updateEntryMod(_scope.entryId, modId, name, url, _scope.spaceId);
    _ref.invalidate(entryModsProvider(_scope));
  }

  Future<void> remove(int modId) async {
    await _ref
        .read(backlogApiProvider)
        .deleteEntryMod(_scope.entryId, modId, _scope.spaceId);
    _ref.invalidate(entryModsProvider(_scope));
  }
}

final entryModActionsProvider = Provider.family<EntryModActions, ModsScope>(
  EntryModActions.new,
);
