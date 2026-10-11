import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the widget that plays [embedUrl] inside the app, or null on a
/// platform that has no embedded player (the trailer then opens in the
/// browser). Tests replace it with a placeholder, because a web view needs a
/// real window.
typedef TrailerPlayerBuilder = Widget? Function(
  BuildContext context,
  Uri embedUrl,
);

/// The player of the app: the system web view (WKWebView, WebView2) on macOS
/// and Windows; the web view plugin has no Linux implementation. Navigation
/// stays on the YouTube hosts, every other address is cancelled.
Widget? systemTrailerPlayer(BuildContext context, Uri embedUrl) {
  final supported =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;
  if (!supported) return null;
  return InAppWebView(
    key: const Key('trailer-webview'),
    initialUrlRequest: URLRequest(url: WebUri.uri(embedUrl)),
    shouldOverrideUrlLoading: (controller, action) async {
      final host = action.request.url?.host ?? '';
      final embedded =
          host == 'www.youtube-nocookie.com' || host == 'www.youtube.com';
      return embedded
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL;
    },
    initialSettings: InAppWebViewSettings(
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      transparentBackground: true,
    ),
  );
}

final trailerPlayerBuilderProvider = Provider<TrailerPlayerBuilder>(
  (ref) => systemTrailerPlayer,
);
