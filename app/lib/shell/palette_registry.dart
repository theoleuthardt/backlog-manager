import 'package:backlog_manager/domain/palette_search.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shortcut of a palette action: Cmd (macOS) or Ctrl plus [key], with
/// Shift when [shift] is set.
class PaletteShortcut {
  const PaletteShortcut(this.key, {this.shift = false});

  final LogicalKeyboardKey key;
  final bool shift;

  SingleActivator activator({required bool isMac}) =>
      SingleActivator(key, meta: isMac, control: !isMac, shift: shift);

  /// "⌘⇧S" on macOS, "Ctrl+Shift+S" elsewhere.
  String display({required bool isMac}) {
    final label = key.keyLabel;
    return isMac
        ? '⌘${shift ? '⇧' : ''}$label'
        : 'Ctrl+${shift ? 'Shift+' : ''}$label';
  }
}

/// Something the command palette can run, and the shortcut that runs it
/// without the palette.
class PaletteAction {
  const PaletteAction({
    required this.id,
    required this.label,
    required this.run,
    this.shortcut,
  });

  final String id;
  final String label;
  final PaletteShortcut? shortcut;
  final void Function() run;
}

/// The actions of the palette. Every feature registers its own with a stable
/// [PaletteAction.id]; registering an id again replaces that action in place.
/// The palette lists them and the window binds their shortcuts, so the hints
/// and the keys cannot differ.
class PaletteRegistry extends Notifier<List<PaletteAction>> {
  @override
  List<PaletteAction> build() => const [];

  void register(PaletteAction action) {
    final index = state.indexWhere((candidate) => candidate.id == action.id);
    state = index < 0
        ? [...state, action]
        : [
            for (var i = 0; i < state.length; i++)
              i == index ? action : state[i],
          ];
  }

  void unregister(String id) {
    state = [
      for (final action in state)
        if (action.id != id) action,
    ];
  }
}

final paletteRegistryProvider =
    NotifierProvider<PaletteRegistry, List<PaletteAction>>(PaletteRegistry.new);

/// The actions that match [query], all of them in registration order for an
/// empty query and the best match first otherwise.
List<PaletteAction> actionsMatching(List<PaletteAction> actions, String query) {
  if (query.trim().isEmpty) return actions;
  final scored = <(PaletteAction, int)>[];
  for (final action in actions) {
    final score = fuzzyScore(query, action.label);
    if (score != null) scored.add((action, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final item in scored) item.$1];
}
