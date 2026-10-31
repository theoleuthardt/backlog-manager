import 'dart:async';

import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/gamepad.dart';
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

/// A button of a gamepad, see [gamepadActionFor].
class GamepadIntent extends Intent {
  const GamepadIntent(this.action);

  final GamepadAction action;
}

/// Esc: closes the topmost layer of the window, the palette first and then
/// the inspector. The framework's own `DismissIntent` is not used, other
/// widgets answer to it first. It stays disabled while the focus is in a
/// dialog or sheet, so Esc closes that one and leaves the inspector alone.
class CloseTopLayerIntent extends Intent {
  const CloseTopLayerIntent();
}

bool _typingInTextField() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<EditableText>() != null;
}

bool _focusInPopupRoute() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null && ModalRoute.of(context) is PopupRoute;
}

/// The keyboard shortcuts of the whole window: Cmd+S on macOS and Ctrl+S
/// elsewhere focus the search field of the library (on a page without it they
/// open the command palette; not while typing in a text field and not with a
/// sheet or popover open), Cmd+K and Ctrl+K open the command palette, Esc closes the palette and then the inspector.
/// The shortcuts of the palette actions come from the registry. On a touch
/// screen the buttons of a gamepad work too ([GamepadAction]), and the D-pad
/// finds the first control when nothing has the focus yet.
class ShellShortcuts extends ConsumerWidget {
  const ShellShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final registered = ref.watch(paletteRegistryProvider);
    final touch = ShelfFormFactor.isTouch(context);
    final signedIn = ref.watch(sessionProvider) is SessionSignedIn;
    return Shortcuts(
      shortcuts: {
        if (touch)
          for (final key in _gamepadKeys)
            SingleActivator(key): GamepadIntent(gamepadActionFor(key)!),
        for (final action in registered)
          if (action.shortcut != null)
            action.shortcut!.activator(isMac: isMac): RunPaletteActionIntent(
              action,
            ),
        SingleActivator(LogicalKeyboardKey.keyS, meta: isMac, control: !isMac):
            const FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: isMac, control: !isMac):
            const OpenPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const CloseTopLayerIntent(),
      },
      child: Actions(
        actions: {
          FocusSearchIntent: _Action<FocusSearchIntent>(
            enabled: () => !_typingInTextField() && !_focusInPopupRoute(),
            run: () {
              final node = ref.read(searchFocusNodeProvider);
              if (node.context != null) {
                node.requestFocus();
              } else if (ref.read(sessionProvider) is SessionSignedIn) {
                ref.read(paletteOpenProvider.notifier).open();
              }
            },
          ),
          RunPaletteActionIntent: _RunPaletteAction(
            enabled: () => ref.read(sessionProvider) is SessionSignedIn,
          ),
          OpenPaletteIntent: _Action<OpenPaletteIntent>(
            enabled: () => ref.read(sessionProvider) is SessionSignedIn,
            run: () => ref.read(paletteOpenProvider.notifier).open(),
          ),
          if (touch) ...{
            GamepadIntent: _GamepadAction(ref, signedIn: signedIn),
            DirectionalFocusIntent: _DpadFocusAction(),
          },
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

class _RunPaletteAction extends Action<RunPaletteActionIntent> {
  _RunPaletteAction({required this.enabled});

  final bool Function() enabled;

  @override
  bool isEnabled(RunPaletteActionIntent intent) => enabled();

  @override
  Object? invoke(RunPaletteActionIntent intent) {
    intent.action.run();
    return null;
  }
}

const _gamepadKeys = [
  LogicalKeyboardKey.gameButtonB,
  LogicalKeyboardKey.gameButtonY,
  LogicalKeyboardKey.gameButtonLeft1,
  LogicalKeyboardKey.gameButtonRight1,
  LogicalKeyboardKey.gameButtonStart,
];

class _GamepadAction extends Action<GamepadIntent> {
  _GamepadAction(this.ref, {required this.signedIn});

  final WidgetRef ref;
  final bool signedIn;

  @override
  bool isEnabled(GamepadIntent intent) =>
      intent.action == GamepadAction.back || (signedIn && !behindLock(ref));

  @override
  Object? invoke(GamepadIntent intent) {
    final router = ref.read(routerProvider);
    final location = router.routerDelegate.currentConfiguration.uri.path;
    final adding = ref.read(addGameOpenProvider);
    void goToSection(String section) {
      if (section == addGameSection) {
        ref.read(addGameRequestProvider.notifier).request();
        return;
      }
      if (adding) router.routerDelegate.navigatorKey.currentState?.pop();
      router.go(section);
    }

    switch (intent.action) {
      case GamepadAction.back:
        unawaited(navigateBack(ref));
      case GamepadAction.search:
        ref.read(paletteOpenProvider.notifier).open();
      case GamepadAction.previousSection:
        goToSection(sectionAfter(location, forward: false, adding: adding));
      case GamepadAction.nextSection:
        goToSection(sectionAfter(location, forward: true, adding: adding));
      case GamepadAction.settings:
        router.go(AppRoutes.settings);
      case GamepadAction.menu:
        break;
    }
    return null;
  }
}

/// The D-pad: moves the focus like the arrow keys, and when nothing has the
/// focus yet it goes to the first control instead of doing nothing.
class _DpadFocusAction extends DirectionalFocusAction {
  @override
  void invoke(DirectionalFocusIntent intent) {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null || focused is FocusScopeNode) {
      (focused ?? FocusManager.instance.rootScope).nextFocus();
      return;
    }
    super.invoke(intent);
  }
}
