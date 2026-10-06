import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class OpenPaletteIntent extends Intent {
  const OpenPaletteIntent();
}

/// Esc: closes the topmost layer of the window, the palette first and then
/// the inspector. The framework's own `DismissIntent` is not used, other
/// widgets answer to it first.
class CloseTopLayerIntent extends Intent {
  const CloseTopLayerIntent();
}

bool _typingInTextField() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// The keyboard shortcuts of the whole window: `/` focuses the search field
/// (not while typing in a text field), Cmd+K on macOS and Ctrl+K elsewhere
/// opens the command palette, Esc closes the palette and then the inspector.
class ShellShortcuts extends ConsumerWidget {
  const ShellShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    return Shortcuts(
      shortcuts: {
        const CharacterActivator('/'): const FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: isMac, control: !isMac):
            const OpenPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const CloseTopLayerIntent(),
      },
      child: Actions(
        actions: {
          FocusSearchIntent: _Action<FocusSearchIntent>(
            enabled: () => !_typingInTextField(),
            run: () => ref.read(searchFocusNodeProvider).requestFocus(),
          ),
          OpenPaletteIntent: _Action<OpenPaletteIntent>(
            enabled: () => ref.read(sessionProvider) is SessionSignedIn,
            run: () => ref.read(paletteOpenProvider.notifier).open(),
          ),
          CloseTopLayerIntent: _Action<CloseTopLayerIntent>(
            enabled: () =>
                ref.read(paletteOpenProvider) ||
                ref.read(shellInspectorProvider) != null,
            run: () {
              if (ref.read(paletteOpenProvider)) {
                ref.read(paletteOpenProvider.notifier).close();
              } else {
                ref.read(shellInspectorProvider.notifier).hide();
              }
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _Action<T extends Intent> extends Action<T> {
  _Action({required this.enabled, required this.run});

  final bool Function() enabled;
  final void Function() run;

  @override
  bool isEnabled(T intent) => enabled();

  @override
  Object? invoke(T intent) {
    run();
    return null;
  }
}
