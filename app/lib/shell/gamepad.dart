import 'dart:async';

import 'package:backlog_manager/auth/biometric_lock.dart';
import 'package:backlog_manager/routing/history.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a button of a gamepad (the Retroid Pocket 6, the AYN Odin 3, a
/// Bluetooth controller) does beyond A, which activates like Enter, and the
/// D-pad, which moves the focus like the arrow keys.
enum GamepadAction {
  /// B: closes the topmost sheet, menu, palette or inspector, else goes back.
  back,

  /// X: the context menu of the focused game (the library tile handles it).
  menu,

  /// Y: the command palette, the search of the whole app.
  search,

  /// L1: the main section before the current one.
  previousSection,

  /// R1: the main section after the current one.
  nextSection,

  /// Start: the settings.
  settings,
}

/// The [GamepadAction] of [key], or null for a key the app leaves to the
/// framework.
GamepadAction? gamepadActionFor(LogicalKeyboardKey key) => switch (key) {
  LogicalKeyboardKey.gameButtonB => GamepadAction.back,
  LogicalKeyboardKey.gameButtonX => GamepadAction.menu,
  LogicalKeyboardKey.gameButtonY => GamepadAction.search,
  LogicalKeyboardKey.gameButtonLeft1 => GamepadAction.previousSection,
  LogicalKeyboardKey.gameButtonRight1 => GamepadAction.nextSection,
  LogicalKeyboardKey.gameButtonStart => GamepadAction.settings,
  _ => null,
};

/// The stop of the shoulder buttons that is "Add" of the bottom bar: the
/// search for a new game, which opens over the page instead of being one.
const addGameSection = 'add-game';

const _sections = [
  AppRoutes.home,
  AppRoutes.library,
  addGameSection,
  AppRoutes.space,
];

/// The main section after (or with [forward] false, before) [location], in
/// the order of the bottom bar (Home, Library, Add, Space); [adding] says
/// that the search for a new game is open, which stands for Add. From any
/// other page R1 and L1 start at Home.
String sectionAfter(
  String location, {
  required bool forward,
  bool adding = false,
}) {
  final index = adding
      ? _sections.indexOf(addGameSection)
      : _sections.indexWhere(
          (route) => route == AppRoutes.home
              ? location == route
              : location == route || location.startsWith('$route/'),
        );
  if (index == -1) return AppRoutes.home;
  final step = forward ? 1 : -1;
  return _sections[(index + step) % _sections.length];
}

/// Whether the biometric lock screen covers the app.
bool behindLock(WidgetRef ref) =>
    ref.read(sessionProvider) is SessionSignedIn &&
    ref.read(biometricUnlockProvider) &&
    ref.read(appLockedProvider);

/// Goes back one step, the way B and the system back of Android do; behind
/// the biometric lock screen it does nothing (and keeps the system from
/// leaving the app), so the hidden app below cannot be moved. An open
/// menu around the focus closes (what Esc does there), the topmost route of
/// the focused navigator pops (a sheet or a dialog; a `PopScope` such as an
/// open settings tab answers it too), then the command palette closes, then
/// the inspector, then the history steps back. False when there is nothing
/// to go back to, so the system may leave the app.
Future<bool> navigateBack(WidgetRef ref) async {
  if (behindLock(ref)) return true;
  final focus = FocusManager.instance.primaryFocus?.context;
  if (focus != null && _dismiss(focus)) return true;
  final navigator = focus == null ? null : Navigator.maybeOf(focus);
  if (navigator != null && await navigator.maybePop()) return true;
  if (!ref.context.mounted) return true;
  if (ref.read(paletteOpenProvider)) {
    ref.read(paletteOpenProvider.notifier).close();
    return true;
  }
  if (ref.read(shellInspectorProvider) != null) {
    ref.read(shellInspectorProvider.notifier).hide();
    return true;
  }
  final target = ref.read(navigationHistoryProvider.notifier).back();
  if (target == null) return false;
  ref.read(routerProvider).go(target);
  return true;
}

/// Answers the system back of Android with [navigateBack] instead of leaving
/// the app at once; it sits below the router, around a page of the app.
class SystemBackHandler extends ConsumerWidget {
  const SystemBackHandler({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BackButtonListener(
    onBackButtonPressed: () => navigateBack(ref),
    child: child,
  );
}

/// The swipe from the left edge of iOS, which has no system back: a drag
/// that starts within [_edgeWidth] of the left edge and goes at least
/// [_swipeDistance] to the right (or is flung there) runs [navigateBack]. It
/// sits above the navigator of the app, so it closes a sheet as well. Android
/// keeps its own back gesture ([SystemBackHandler]).
class EdgeSwipeBack extends ConsumerStatefulWidget {
  const EdgeSwipeBack({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

const _edgeWidth = 20.0;
const _swipeDistance = 80.0;
const _flingVelocity = 500.0;

class _EdgeSwipeBackState extends ConsumerState<EdgeSwipeBack> {
  double _distance = 0;

  void _end(DragEndDetails details) {
    if (_distance >= _swipeDistance ||
        details.primaryVelocity != null &&
            details.primaryVelocity! >= _flingVelocity) {
      unawaited(navigateBack(ref));
    }
    _distance = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _edgeWidth,
          child: GestureDetector(
            key: const Key('edge-swipe-back'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _distance = 0,
            onHorizontalDragUpdate: (details) =>
                _distance += details.primaryDelta ?? 0,
            onHorizontalDragEnd: _end,
          ),
        ),
      ],
    );
  }
}

/// Closes what a [DismissIntent] closes around [focus] (an open menu), and
/// false where only the app's own do-nothing default answers it.
bool _dismiss(BuildContext focus) {
  const intent = DismissIntent();
  final action = Actions.maybeFind<DismissIntent>(focus);
  if (action == null || action is DoNothingAction) return false;
  if (!action.isEnabled(intent)) return false;
  Actions.invoke(focus, intent);
  return true;
}
