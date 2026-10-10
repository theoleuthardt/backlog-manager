import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/palette_registry.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

/// Runs a registered palette action from its own shortcut.
class RunPaletteActionIntent extends Intent {
  const RunPaletteActionIntent(this.action);

  final PaletteAction action;
}

class OpenPaletteIntent extends Intent {
  const OpenPaletteIntent();
}

/// Esc: closes the topmost layer of the window, the palette first and then
/// the inspector. The framework's own `DismissIntent` is not used, other
/// widgets answer to it first. It stays disabled while the focus is in a
/// dialog or sheet, so Esc closes that one and leaves the inspector alone.
class CloseTopLayerIntent extends Intent {
  const CloseTopLayerIntent();
}

bool _focusInPopupRoute() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null && ModalRoute.of(context) is PopupRoute;
}

bool _typingInTextField() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// The keyboard shortcuts of the whole window: `/` focuses the search field
/// (not while typing in a text field), Cmd+K on macOS and Ctrl+K elsewhere
/// opens the command palette, Esc closes the palette and then the inspector.
/// The shortcuts of the palette actions come from the registry.
class ShellShortcuts extends ConsumerWidget {
  const ShellShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final registered = ref.watch(paletteRegistryProvider);
    return Shortcuts(
      shortcuts: {
        for (final action in registered)
          if (action.shortcut != null)
            action.shortcut!.activator(isMac: isMac): RunPaletteActionIntent(
              action,
            ),
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
          RunPaletteActionIntent: CallbackAction<RunPaletteActionIntent>(
            onInvoke: (intent) {
              if (ref.read(sessionProvider) is SessionSignedIn) {
                intent.action.run();
              }
              return null;
            },
          ),
          OpenPaletteIntent: _Action<OpenPaletteIntent>(
            enabled: () => ref.read(sessionProvider) is SessionSignedIn,
            run: () => ref.read(paletteOpenProvider.notifier).open(),
          ),
          CloseTopLayerIntent: _Action<CloseTopLayerIntent>(
            enabled: () =>
                !_focusInPopupRoute() &&
                (ref.read(paletteOpenProvider) ||
                    ref.read(shellInspectorProvider) != null),
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
