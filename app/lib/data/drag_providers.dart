import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The game being dragged in the library and the key of the group the pointer
/// is over, if that group takes a drop.
class DragState {
  const DragState({this.entryId, this.overGroupKey});

  final int? entryId;
  final String? overGroupKey;

  bool get active => entryId != null;
}

class DragNotifier extends Notifier<DragState> {
  @override
  DragState build() {
    ref.watch(sessionGenerationProvider);
    return const DragState();
  }

  void begin(int entryId) => state = DragState(entryId: entryId);

  void over(String? groupKey) {
    if (!state.active || state.overGroupKey == groupKey) return;
    state = DragState(entryId: state.entryId, overGroupKey: groupKey);
  }

  void end() => state = const DragState();
}

final dragProvider = NotifierProvider<DragNotifier, DragState>(
  DragNotifier.new,
);
