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

/// Whether the app is used with a gamepad right now: its buttons or the
/// D-pad were pressed since the screen was last touched. The button hints
/// show while it is.
class GamepadInUseNotifier extends _FlagNotifier {
  void set({required bool inUse}) => state = inUse;
}

final gamepadInUseProvider = NotifierProvider<GamepadInUseNotifier, bool>(
  GamepadInUseNotifier.new,
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

/// Whether the "Search for a game" sheet is open, so the shoulder buttons of
/// a gamepad know that they stand on "Add".
class AddGameOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool open}) => state = open;
}

final addGameOpenProvider = NotifierProvider<AddGameOpenNotifier, bool>(
  AddGameOpenNotifier.new,
);

/// Counts requests to open the IGDB sync sheet (toolbar button, palette).
class IgdbSyncRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final igdbSyncRequestProvider = NotifierProvider<IgdbSyncRequestNotifier, int>(
  IgdbSyncRequestNotifier.new,
);

/// Counts requests to open the random pull sheet (toolbar button, palette).
class RandomPullRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final randomPullRequestProvider =
    NotifierProvider<RandomPullRequestNotifier, int>(
      RandomPullRequestNotifier.new,
    );

/// The focus node of the search field of the library, so Cmd/Ctrl+S can reach
/// it.
final searchFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'search');
  ref.onDispose(node.dispose);
  return node;
});

class _InspectorFullscreenNotifier extends _FlagNotifier {
  void toggle() => state = !state;

  void exit() => state = false;
}

/// Whether the game details fill the whole main pane instead of the slot on
/// its right; the library stays alive behind it.
final inspectorFullscreenProvider =
    NotifierProvider<_InspectorFullscreenNotifier, bool>(
      _InspectorFullscreenNotifier.new,
    );
