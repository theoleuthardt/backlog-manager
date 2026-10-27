import 'package:backlog_manager/platform/desktop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the main window arranges its navigation.
enum ShellLayout {
  /// A phone in portrait: a top bar and a bottom navigation bar.
  compact,

  /// A phone in landscape, the handhelds (Retroid Pocket 6, AYN Odin 3) and a
  /// tablet in portrait: a top bar and a navigation rail.
  medium,

  /// The desktop window: title bar, sidebar, inspector pane and status bar.
  expanded,
}

/// The layout for a window of [size]. The desktop always keeps its full
/// window (its window is at least 1000x640), so its usability never changes;
/// on Android and iOS the available size decides: narrower than 600 is
/// compact, at least 1000 wide and 640 high is expanded, anything between is
/// medium.
ShellLayout shellLayoutFor(Size size, {required bool desktop}) {
  if (desktop) return ShellLayout.expanded;
  if (size.width < 600) return ShellLayout.compact;
  if (size.width >= 1000 && size.height >= 640) return ShellLayout.expanded;
  return ShellLayout.medium;
}

/// [shellLayoutFor] the window of [context] on the platform of [ref].
ShellLayout shellLayoutOf(BuildContext context, WidgetRef ref) =>
    shellLayoutFor(
      MediaQuery.sizeOf(context),
      desktop: ref.watch(isDesktopProvider),
    );
