import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/selection_providers.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/bulk_messages.dart';
import 'package:backlog_manager/domain/drag_drop.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Hands the [LibraryActions] of the library page down to its games and bars.
/// A game that moves to another group is built again, so its own context and
/// ref cannot outlive the action; the page's can.
class LibraryActionsScope extends InheritedWidget {
  const LibraryActionsScope({
    required this.actions,
    required super.child,
    super.key,
  });

  final LibraryActions actions;

  static LibraryActions of(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<LibraryActionsScope>()!
        .actions;
  }

  @override
  bool updateShouldNotify(LibraryActionsScope oldWidget) => false;
}

/// What the library does with games: open one, move one or many to a status
/// or a category, delete, and add or remove categories. Every action reports its outcome in a
/// toast.
class LibraryActions {
  LibraryActions(this._context, this._ref);

  final BuildContext _context;
  final WidgetRef _ref;

  EntriesNotifier get _entries => _ref.read(entriesProvider(null).notifier);

  void _toast(String message, {String? actionLabel, VoidCallback? onAction}) {
    if (!_context.mounted) return;
    showShelfToast(
      _context,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void openDetails(int entryId) {
    _context.go(
      Uri(
        path: AppRoutes.library,
        queryParameters: {'entry': '$entryId'},
      ).toString(),
    );
  }

  /// Moves one game; the toast offers to undo it.
  Future<void> moveEntry(BacklogEntry entry, String status) async {
    final previous = entry.status;
    final failure = await _entries.moveToStatus(entry.id, status);
    if (failure != null) {
      _toast(failure);
      return;
    }
    _toast(
      'Moved "${entry.title}" to $status',
      actionLabel: 'Undo',
      onAction: () => _entries.moveToStatus(entry.id, previous),
    );
  }

  /// Moves one game to a category: the category is added and the game's first
  /// one is removed. Dropping a game on the category it is already in does
  /// nothing.
  Future<void> moveToCategory(BacklogEntry entry, Category target) async {
    final assigned =
        _ref.read(entryCategoriesProvider(null)).value?[entry.id] ??
        const <Category>[];
    final move = categoryMove(assigned: assigned, target: target);
    if (move == null) return;
    final actions = _ref.read(categoryActionsProvider(null));
    final add = move.add;
    final remove = move.remove;
    var added = false;
    try {
      if (add != null) {
        await actions.setAssigned(entry.id, add.id, assigned: true);
        added = true;
      }
      if (remove != null) {
        await actions.setAssigned(entry.id, remove.id, assigned: false);
      }
      _toast('Moved "${entry.title}" to ${target.name}');
    } on Object catch (error) {
      _toast(
        added && remove != null
            ? 'Added to ${target.name} but could not remove ${remove.name}'
            : ApiException.from(error, 'Failed to change category').message,
      );
    }
  }

  Future<void> setStatusOfMany(List<int> entryIds, String status) async {
    try {
      final result = await _entries.setStatusOfMany(entryIds, status);
      _toast(
        bulkStatusMessage(
          succeeded: result.succeeded.length,
          failed: result.failed.length,
          status: status,
        ),
      );
    } on Object catch (error) {
      _toast(ApiException.from(error, 'Failed to change status').message);
    }
  }

  /// Asks before deleting [entries] and deletes them one request per game.
  Future<void> deleteEntries(List<BacklogEntry> entries) async {
    if (entries.isEmpty) return;
    final result = await showShelfSheet<BulkResult>(
      _context,
      builder: (context) => _DeleteSheet(entries: entries),
    );
    if (result == null) return;
    _ref.read(selectionProvider.notifier).removeAll(result.succeeded);
    _toast(
      bulkDeleteMessage(
        succeeded: result.succeeded.length,
        failed: result.failed.length,
        singleTitle: entries.length == 1 ? entries.single.title : null,
      ),
    );
  }

  Future<void> setCategory(
    int entryId,
    int categoryId, {
    required bool assigned,
  }) async {
    try {
      await _ref
          .read(categoryActionsProvider(null))
          .setAssigned(entryId, categoryId, assigned: assigned);
    } on Object catch (error) {
      _toast(ApiException.from(error, 'Failed to update categories').message);
    }
  }

  Future<void> setCategoryOfMany(
    List<int> entryIds,
    Category category, {
    required bool assigned,
  }) async {
    try {
      final result = await _ref
          .read(categoryActionsProvider(null))
          .setAssignedMany(entryIds, category.id, assigned: assigned);
      _toast(
        bulkCategoryMessage(
          added: assigned,
          category: category.name,
          succeeded: result.succeeded.length,
          failed: result.failed.length,
        ),
      );
    } on Object catch (error) {
      _toast(ApiException.from(error, 'Failed to update categories').message);
    }
  }
}

class _DeleteSheet extends ConsumerStatefulWidget {
  const _DeleteSheet({required this.entries});

  final List<BacklogEntry> entries;

  @override
  ConsumerState<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends ConsumerState<_DeleteSheet> {
  bool _busy = false;

  Future<void> _delete() async {
    setState(() => _busy = true);
    final result = await ref.read(entriesProvider(null).notifier).deleteMany([
      for (final entry in widget.entries) entry.id,
    ]);
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return ShelfSheet(
      title: deleteTitle([for (final entry in widget.entries) entry.title]),
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: _busy ? null : () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('delete-confirm'),
          label: _busy ? 'Deleting...' : 'Delete',
          kind: ShelfButtonKind.danger,
          busy: _busy,
          onPressed: _delete,
        ),
      ),
      child: Text(deleteDescription(widget.entries.length)),
    );
  }
}
