import 'dart:convert';

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
    initialData: InAppWebViewInitialData(
      data: trailerPage(embedUrl),
      baseUrl: WebUri('https://www.youtube.com/'),
    ),
    shouldOverrideUrlLoading: (controller, action) async {
      final host = action.request.url?.host ?? '';
      final embedded =
          !action.isForMainFrame ||
          host == 'www.youtube-nocookie.com' ||
          host == 'www.youtube.com';
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

/// The page the web view loads: the embed in a frame that fills the view. YouTube
/// answers error 153 to an embed that is opened as a top-level address, because
/// the player is given no referrer; a page with a YouTube origin around the
/// frame gives it one.
String trailerPage(Uri embedUrl) {
  final src = const HtmlEscape(HtmlEscapeMode.attribute).convert('$embedUrl');
  return '<!doctype html><html><head><meta charset="utf-8">'
      '<meta name="referrer" content="strict-origin-when-cross-origin">'
      '<style>html,body{margin:0;height:100%;background:#000}'
      'iframe{border:0;width:100%;height:100%}</style></head><body>'
      '<iframe src="$src" allow="autoplay; encrypted-media; picture-in-picture" '
      'allowfullscreen referrerpolicy="strict-origin-when-cross-origin">'
      '</iframe></body></html>';
}

final trailerPlayerBuilderProvider = Provider<TrailerPlayerBuilder>(
  (ref) => systemTrailerPlayer,
);
