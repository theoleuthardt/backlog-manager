import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pages visited in this window, for the back and forward buttons of the
/// title bar (`go_router` keeps no history of its own that can be walked).
class NavigationHistory {
  const NavigationHistory({this.entries = const [], this.index = -1});

  final List<String> entries;
  final int index;

  bool get canGoBack => index > 0;

  bool get canGoForward => index >= 0 && index < entries.length - 1;
}

class NavigationHistoryNotifier extends Notifier<NavigationHistory> {
  @override
  NavigationHistory build() => const NavigationHistory();

  /// Records [location] as the current page; coming back to the page the
  /// history already points at (after back or forward) changes nothing, and a
  /// new page drops the forward entries.
  void visit(String location) {
    if (state.index >= 0 && state.entries[state.index] == location) return;
    final kept = state.entries.sublist(0, state.index + 1);
    state = NavigationHistory(entries: [...kept, location], index: kept.length);
  }

  /// Moves one page back and returns it, or null at the start.
  String? back() {
    if (!state.canGoBack) return null;
    state = NavigationHistory(entries: state.entries, index: state.index - 1);
    return state.entries[state.index];
  }

  /// Moves one page forward and returns it, or null at the end.
  String? forward() {
    if (!state.canGoForward) return null;
    state = NavigationHistory(entries: state.entries, index: state.index + 1);
    return state.entries[state.index];
  }

  void reset() => state = const NavigationHistory();
}

final navigationHistoryProvider =
    NotifierProvider<NavigationHistoryNotifier, NavigationHistory>(
      NavigationHistoryNotifier.new,
    );
