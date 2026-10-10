import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the library is in selection mode and which games are selected.
class SelectionState {
  const SelectionState({this.active = false, this.ids = const {}});

  final bool active;
  final Set<int> ids;
}

/// The selection of the library. It stays while the user moves between
/// screens and is forgotten with the next session.
class SelectionNotifier extends Notifier<SelectionState> {
  @override
  SelectionState build() {
    ref.watch(sessionGenerationProvider);
    return const SelectionState();
  }

  /// Turns selection mode on with nothing selected.
  void begin() => state = const SelectionState(active: true);

  /// Turns selection mode on with just [id] selected.
  void start(int id) => state = SelectionState(active: true, ids: {id});

  void toggle(int id) {
    final next = {...state.ids};
    if (!next.remove(id)) next.add(id);
    state = SelectionState(active: state.active, ids: next);
  }

  void selectAll(Iterable<int> ids) {
    state = SelectionState(active: state.active, ids: {...ids});
  }

  void removeAll(Iterable<int> ids) {
    final next = {...state.ids}..removeAll(ids);
    state = SelectionState(active: state.active, ids: next);
  }

  void clear() => state = SelectionState(active: state.active);

  void end() => state = const SelectionState();
}

final selectionProvider = NotifierProvider<SelectionNotifier, SelectionState>(
  SelectionNotifier.new,
);
