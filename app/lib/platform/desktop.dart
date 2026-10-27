import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app runs on a desktop system (macOS, Windows, Linux), the only
/// systems with a window of its own and the desktop plugins `window_manager`,
/// `desktop_webview_window` and `desktop_drop`. [operatingSystem] defaults to
/// the system the app runs on; it is the real one, not Flutter's
/// `defaultTargetPlatform`, which widget tests report as Android.
bool isDesktopPlatform({String? operatingSystem}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  return os == 'macos' || os == 'windows' || os == 'linux';
}

/// [isDesktopPlatform] for the widgets and providers that depend on it, so
/// tests can take the Android and iOS branches.
final isDesktopProvider = Provider<bool>((ref) => isDesktopPlatform());
