import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LibraryLayout { grid, list }

/// Covers a group shows before "Show more", and what each click adds.
const groupPageSize = 60;

/// How the library looks right now: the sort, the layout, which groups are
/// folded away and how many covers each group has revealed. Collapsed groups
/// are keyed by sort option and group, so each sort keeps its own.
class LibraryViewState {
  const LibraryViewState({
    required this.sortBy,
    required this.direction,
    this.layout = LibraryLayout.grid,
    this.collapsed = const {},
    this.extraPages = const {},
  });

  final SortOption sortBy;
  final SortDirection direction;
  final LibraryLayout layout;
  final Set<String> collapsed;
  final Map<String, int> extraPages;

  bool isCollapsed(String groupKey) => collapsed.contains(groupKey);

  int visibleIn(String groupKey) =>
      groupPageSize * (1 + (extraPages[groupKey] ?? 0));

  LibraryViewState copyWith({
    SortOption? sortBy,
    SortDirection? direction,
    LibraryLayout? layout,
    Set<String>? collapsed,
    Map<String, int>? extraPages,
  }) {
    return LibraryViewState(
      sortBy: sortBy ?? this.sortBy,
      direction: direction ?? this.direction,
      layout: layout ?? this.layout,
      collapsed: collapsed ?? this.collapsed,
      extraPages: extraPages ?? this.extraPages,
    );
  }
}

class LibraryViewNotifier extends Notifier<LibraryViewState> {
  @override
  LibraryViewState build() {
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
