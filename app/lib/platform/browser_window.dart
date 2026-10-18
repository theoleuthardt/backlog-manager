import 'dart:async';
import 'dart:io';

import 'package:backlog_manager/domain/safe_url.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens [url] in a browser window of the app. [stays] decides for every
/// further page the window is about to load whether it loads there; a page it
/// declines opens in the system browser instead.
typedef BrowserWindowOpener = Future<void> Function(
  Uri url, {
  required bool Function(Uri url) stays,
});

/// The folder WebView2 keeps its profile in on Windows: the plugin puts it
/// next to the executable by default, which fails where the app is installed
/// in a folder that is not writable. Null without a local application data
/// folder.
String? windowsWebviewProfileFolder(Map<String, String> environment) {
  final base = environment['LOCALAPPDATA'];
  if (base == null || base.isEmpty) return null;
  return '$base\\Backlog Manager\\WebView2';
}

/// The browser window of the app: the system web view (WebKitGTK, WebView2,
/// WKWebView) in a window of its own, one at a time (a second call closes the
/// first). Where the web view is not available, for example on Windows
/// without the WebView2 runtime, or when the window cannot be created, the
/// address opens in the system browser. Tests replace it.
final browserWindowOpenerProvider = Provider<BrowserWindowOpener>((ref) {
  final openExternally = ref.watch(urlOpenerProvider);
  Webview? current;

  return (url, {required stays}) async {
    try {
      if (!await WebviewWindow.isWebviewAvailable()) {
        openExternally(url);
        return;
      }
      await current?.close();
      final profile = Platform.isWindows
          ? windowsWebviewProfileFolder(Platform.environment)
          : null;
      final window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 1100,
          windowHeight: 800,
          windows: profile == null
              ? const WindowsWebviewOptions()
              : WindowsWebviewOptions(userDataFolder: profile),
        ),
      );
      current = window;
      unawaited(
        window.onClose.then((_) {
          if (identical(current, window)) current = null;
        }),
      );
      await window.setOnUrlRequestCallback((address) {
        final target = Uri.tryParse(address);
        if (target != null && stays(target)) return true;
        if (target != null && isHttpUrl(address)) openExternally(target);
        return false;
      });
      await window.launch(url.toString(), triggerOnUrlRequestEvent: false);
    } on Object {
      openExternally(url);
    }
  };
});
