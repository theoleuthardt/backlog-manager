import 'dart:io';

/// Whether the app runs on a desktop system (macOS, Windows, Linux), the only
/// systems with a window of its own and the desktop plugins `window_manager`,
/// `desktop_webview_window` and `desktop_drop`. [operatingSystem] defaults to
/// the system the app runs on; it is the real one, not Flutter's
/// `defaultTargetPlatform`, which widget tests report as Android.
bool isDesktopPlatform({String? operatingSystem}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  return os == 'macos' || os == 'windows' || os == 'linux';
}
