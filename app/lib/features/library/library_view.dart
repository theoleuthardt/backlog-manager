import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/domain/entry_order.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LibraryLayout { grid, list }

/// Covers a group shows before "Show more", and what each click adds.
const groupPageSize = 60;

/// How the library looks right now: the sort, the layout, which groups are
/// folded away, how many covers each group has revealed and how the games of
/// a group are ordered when its header says so. Collapsed groups and orders
/// are keyed by sort option and group, so each sort keeps its own.
class LibraryViewState {
  const LibraryViewState({
    required this.sortBy,
    required this.direction,
    this.layout = LibraryLayout.grid,
    this.collapsed = const {},
    this.extraPages = const {},
    this.entryOrders = const {},
    this.reorderingGroups = false,
  });

  final SortOption sortBy;
  final SortDirection direction;
  final LibraryLayout layout;
  final Set<String> collapsed;
  final Map<String, int> extraPages;

  /// The order of the games of a group, by group key; a group without one
  /// keeps the order of the sort.
  final Map<String, EntryOrder> entryOrders;

  /// Whether a group header is being dragged to another place: every group
  /// folds away meanwhile, so all headers are in view as drop targets.
  final bool reorderingGroups;

  bool isCollapsed(String groupKey) => collapsed.contains(groupKey);

  int visibleIn(String groupKey) =>
      groupPageSize * (1 + (extraPages[groupKey] ?? 0));

  LibraryViewState copyWith({
    SortOption? sortBy,
    SortDirection? direction,
    LibraryLayout? layout,
    Set<String>? collapsed,
    Map<String, int>? extraPages,
    Map<String, EntryOrder>? entryOrders,
    bool? reorderingGroups,
  }) {
    return LibraryViewState(
      sortBy: sortBy ?? this.sortBy,
      direction: direction ?? this.direction,
      layout: layout ?? this.layout,
      collapsed: collapsed ?? this.collapsed,
      extraPages: extraPages ?? this.extraPages,
      entryOrders: entryOrders ?? this.entryOrders,
      reorderingGroups: reorderingGroups ?? this.reorderingGroups,
    );
  }
}

class LibraryViewNotifier extends Notifier<LibraryViewState> {
  @override
  LibraryViewState build() {
    ref.watch(sessionGenerationProvider);
    final session = ref.read(sessionProvider);
    final stored = session is SessionSignedIn
        ? parseSortOption(session.user.defaultSort)
        : null;
    final sortBy = stored ?? defaultSort;
    return LibraryViewState(
      sortBy: sortBy,
      direction: defaultDirectionFor(sortBy),
    );
  }

  void setSort(SortOption sortBy) {
    state = state.copyWith(
      sortBy: sortBy,
      direction: defaultDirectionFor(sortBy),
    );
  }

  void toggleDirection() {
    state = state.copyWith(
      direction: state.direction == SortDirection.asc
          ? SortDirection.desc
          : SortDirection.asc,
    );
  }

  void setLayout(LibraryLayout layout) {
    state = state.copyWith(layout: layout);
  }

  void toggleCollapsed(String groupKey) {
    final next = {...state.collapsed};
    if (!next.remove(groupKey)) next.add(groupKey);
    state = state.copyWith(collapsed: next);
  }

  void setReorderingGroups({required bool active}) {
    if (state.reorderingGroups == active) return;
    state = state.copyWith(reorderingGroups: active);
  }

  /// Orders the games of the group [groupKey] by [order], or as the sort
  /// does again for null.
  void setEntryOrder(String groupKey, EntryOrder? order) {
    final next = {...state.entryOrders};
    if (order == null) {
      next.remove(groupKey);
    } else {
      next[groupKey] = order;
    }
    state = state.copyWith(entryOrders: next);
  }

  void showMore(String groupKey) {
    state = state.copyWith(
      extraPages: {
        ...state.extraPages,
        groupKey: (state.extraPages[groupKey] ?? 0) + 1,
      },
    );
  }
}

final libraryViewProvider =
    NotifierProvider<LibraryViewNotifier, LibraryViewState>(
      LibraryViewNotifier.new,
    );
