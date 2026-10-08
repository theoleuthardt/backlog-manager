import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/text_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How a change of many entries went: one request per entry, so some can fail.
class BulkResult {
  const BulkResult({required this.succeeded, required this.failed});

  final List<int> succeeded;
  final List<int> failed;
}

/// The entries of one backlog: the personal one (`spaceId` null) or a shared
/// space. The scope is the key of the provider, so the two never share data,
/// and the data is dropped when the session generation changes, so the next
/// user never sees the previous one's entries.
class EntriesNotifier extends AsyncNotifier<List<BacklogEntry>> {
  EntriesNotifier(this.spaceId);

  final int? spaceId;
  int _pendingMoves = 0;

  BacklogApi get _api => ref.read(backlogApiProvider);

  @override
  Future<List<BacklogEntry>> build() {
    ref.watch(sessionGenerationProvider);
    return _api.entries(spaceId);
  }

  /// Loads the list again without showing a loading state. When the reload
  /// fails the list on screen stays as it is.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _api.entries(spaceId));
    } on Object {
      return;
    }
  }

  Future<void> createEntry(wire.CreateBacklogEntryRequest request) async {
    await _api.createEntry(request, spaceId);
    await refresh();
  }

  Future<void> updateEntry(int entryId, EntryUpdate update) async {
    await _api.updateEntry(entryId, update, spaceId);
    await refresh();
  }

  Future<void> deleteEntry(int entryId) async {
    await _api.deleteEntry(entryId, spaceId);
    await refresh();
  }

  /// Moves an entry to another status. The list changes at once so the card
  /// jumps groups without waiting for the round trip. A failed request puts
  /// back only that entry: a second move that is still running has changed
  /// the same list, and restoring all of it would undo that one too. The list
  /// is reloaded only when no other move is still running, because a reload
  /// in between would bring back the old state of that other move.
  /// Returns the error message of a failed move, or null.
  Future<String?> moveToStatus(int entryId, String status) async {
    final previous = state.value
        ?.where((e) => e.id == entryId)
        .firstOrNull
        ?.status;
    _setStatus(entryId, status);
    _pendingMoves++;
    String? failure;
    try {
      await _api.updateEntry(entryId, EntryUpdate(status: status), spaceId);
    } on Object catch (error) {
      failure = ApiException.from(error, 'Could not move the game').message;
      if (previous != null) _setStatus(entryId, previous);
    } finally {
      _pendingMoves--;
    }
    if (_pendingMoves == 0) await refresh();
    return failure;
  }

  Future<BulkResult> setStatusOfMany(List<int> entryIds, String status) {
    return _forEach(
      entryIds,
      (id) => _api.updateEntry(id, EntryUpdate(status: status), spaceId),
    );
  }

  Future<BulkResult> deleteMany(List<int> entryIds) {
    return _forEach(entryIds, (id) => _api.deleteEntry(id, spaceId));
  }

  Future<BulkResult> _forEach(
    List<int> ids,
    Future<Object?> Function(int id) action,
  ) async {
    final succeeded = <int>[];
    final failed = <int>[];
    for (var start = 0; start < ids.length; start += _bulkBatchSize) {
      final batch = ids.skip(start).take(_bulkBatchSize);
      await Future.wait([
        for (final id in batch)
          action(id).then<void>(
            (_) => succeeded.add(id),
            onError: (Object _) => failed.add(id),
          ),
      ]);
    }
    await refresh();
    succeeded.sort();
    failed.sort();
    return BulkResult(succeeded: succeeded, failed: failed);
  }

  void _setStatus(int entryId, String status) {
    final entries = state.value;
    if (entries == null) return;
    state = AsyncData([
      for (final entry in entries)
        entry.id == entryId ? entry.withStatus(status) : entry,
    ]);
  }
}

/// How many requests of a bulk action run at the same time.
const _bulkBatchSize = 8;

final entriesProvider =
    AsyncNotifierProvider.family<EntriesNotifier, List<BacklogEntry>, int?>(
      EntriesNotifier.new,
    );

/// The custom statuses of a backlog.
final customStatusesProvider = FutureProvider.family<List<CustomStatus>, int?>((
  ref,
  spaceId,
) {
  ref.watch(sessionGenerationProvider);
  return ref.watch(backlogApiProvider).customStatuses(spaceId);
});

/// Creates and deletes the custom statuses of one backlog; the list of the
/// statuses is read again afterwards.
class CustomStatusActions {
  CustomStatusActions(this._ref, this._spaceId);

  final Ref _ref;
  final int? _spaceId;

  Future<CustomStatus> create(String name) async {
    final created = await _ref
        .read(backlogApiProvider)
        .createCustomStatus(name, _spaceId);
    _ref.invalidate(customStatusesProvider(_spaceId));
    return created;
  }

  Future<void> delete(int statusId) async {
    await _ref.read(backlogApiProvider).deleteCustomStatus(statusId, _spaceId);
    _ref.invalidate(customStatusesProvider(_spaceId));
  }
}

final customStatusActionsProvider = Provider.family<CustomStatusActions, int?>(
  CustomStatusActions.new,
);

/// Creates, changes, deletes and assigns the categories of one backlog; the
/// categories and the map from entries to categories are read again after
/// every change, so the library, the filters and the sorting follow.
class CategoryActions {
  CategoryActions(this._ref, this._spaceId);

  final Ref _ref;
  final int? _spaceId;

  BacklogApi get _api => _ref.read(backlogApiProvider);

  void _changed() {
    _ref
      ..invalidate(categoriesProvider(_spaceId))
      ..invalidate(entryCategoriesProvider(_spaceId));
  }

  Future<Category> create(String name, String color) async {
    final created = await _api.createCategory(name, color, _spaceId);
    _changed();
    return created;
  }

  Future<void> update(int categoryId, {String? name, String? color}) async {
    await _api.updateCategory(categoryId, _spaceId, name: name, color: color);
    _changed();
  }

  Future<void> delete(int categoryId) async {
    await _api.deleteCategory(categoryId, _spaceId);
    _changed();
  }

  Future<void> setAssigned(
    int entryId,
    int categoryId, {
    required bool assigned,
  }) async {
    await _api.setEntryCategory(
      entryId,
      categoryId,
      _spaceId,
      assigned: assigned,
    );
    _changed();
  }
}

final categoryActionsProvider = Provider.family<CategoryActions, int?>(
  CategoryActions.new,
);

/// Every category of a backlog.
final categoriesProvider = FutureProvider.family<List<Category>, int?>((
  ref,
  spaceId,
) {
  ref.watch(sessionGenerationProvider);
  return ref.watch(backlogApiProvider).categories(spaceId);
});

/// Maps an entry id to the categories it belongs to, alphabetical by name.
/// Entries carry no category data themselves, so this asks the entries of
/// every category; it is the one source for sorting, grouping and filtering by
/// category.
final entryCategoriesProvider =
    FutureProvider.family<Map<int, List<Category>>, int?>((ref, spaceId) async {
      ref.watch(sessionGenerationProvider);
      final api = ref.watch(backlogApiProvider);
      final categories = [...await api.categories(spaceId)]
        ..sort((a, b) => compareBase(a.name, b.name));
      final entriesPerCategory = await Future.wait([
        for (final category in categories)
          api.entriesOfCategory(category.id, spaceId),
      ]);
      final byEntry = <int, List<Category>>{};
      for (var i = 0; i < categories.length; i++) {
        for (final entry in entriesPerCategory[i]) {
          byEntry.putIfAbsent(entry.id, () => []).add(categories[i]);
        }
      }
      return byEntry;
    });
