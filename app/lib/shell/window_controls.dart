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

final windowControlsProvider = Provider<WindowControls>(
  (ref) => PluginWindowControls(),
);
