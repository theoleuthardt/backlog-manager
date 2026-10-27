import 'package:backlog_manager/platform/desktop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// What the title bar asks of the native window.
abstract interface class WindowControls {
  Future<void> minimize();

  Future<void> toggleMaximize();

  Future<void> close();

  Future<void> startDragging();
}

/// The native window, through the `window_manager` plugin.
class PluginWindowControls implements WindowControls {
  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();
}

/// A phone or tablet: the system owns the window, so there is nothing to
/// minimize, maximize, close or drag.
class NoWindowControls implements WindowControls {
  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> startDragging() async {}
}

final windowControlsProvider = Provider<WindowControls>(
  (ref) => ref.watch(isDesktopProvider)
      ? PluginWindowControls()
      : NoWindowControls(),
);
