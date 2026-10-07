import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the screens put into the status bar.
class ShellStatus {
  const ShellStatus({this.counts, this.sync});

  final String? counts;
  final String? sync;
}

class ShellStatusNotifier extends Notifier<ShellStatus> {
  @override
  ShellStatus build() => const ShellStatus();

  void update({String? counts, String? sync}) {
    state = ShellStatus(
      counts: counts ?? state.counts,
      sync: sync ?? state.sync,
    );
  }

  void clear() => state = const ShellStatus();
}

final shellStatusProvider = NotifierProvider<ShellStatusNotifier, ShellStatus>(
  ShellStatusNotifier.new,
);

/// The widget in the inspector slot on the right of the main pane, if any.
class ShellInspectorNotifier extends Notifier<Widget?> {
  @override
  Widget? build() => null;

  void show(Widget inspector) => state = inspector;

  void hide() => state = null;
}

final shellInspectorProvider =
    NotifierProvider<ShellInspectorNotifier, Widget?>(
      ShellInspectorNotifier.new,
    );

class _FlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

/// Whether the command palette is open (Cmd/Ctrl+K opens it, Esc closes it).
class PaletteOpenNotifier extends _FlagNotifier {
  void open() => state = true;

  void close() => state = false;
}

final paletteOpenProvider = NotifierProvider<PaletteOpenNotifier, bool>(
  PaletteOpenNotifier.new,
);

/// Whether the sidebar is collapsed from the title bar.
class SidebarCollapsedNotifier extends _FlagNotifier {
  void toggle() => state = !state;
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
      SidebarCollapsedNotifier.new,
    );

/// How often "Add game" was asked for; the add-a-game sheet listens to it.
class AddGameRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final addGameRequestProvider = NotifierProvider<AddGameRequestNotifier, int>(
  AddGameRequestNotifier.new,
);

/// The focus node of the search field in the title bar, so `/` can reach it.
final searchFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'search');
  ref.onDispose(node.dispose);
  return node;
});
