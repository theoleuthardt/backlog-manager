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
      baseUrl: WebUri('$trailerOrigin/'),
    ),
    shouldOverrideUrlLoading: (controller, action) async {
      final host = action.request.url?.host ?? '';
      final embedded =
          !action.isForMainFrame ||
          host == Uri.parse(trailerOrigin).host ||
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

/// The origin the app presents to YouTube: its application id as an https
/// address. YouTube identifies an embedding client by the origin of the page
/// around the frame; a page without one gets error 153, a page that claims to
/// be youtube.com gets error 152.
const trailerOrigin = 'https://dev.theocloud.blm';

/// The page the web view loads: the embed in a frame that fills the view,
/// told which origin embeds it.
String trailerPage(Uri embedUrl) {
  final withOrigin = embedUrl.replace(
    queryParameters: {
      ...embedUrl.queryParameters,
      'origin': trailerOrigin,
      'widget_referrer': trailerOrigin,
    },
  );
  final src = const HtmlEscape(HtmlEscapeMode.attribute).convert('$withOrigin');
  return '<!doctype html><html><head><meta charset="utf-8">'
      '<meta name="referrer" content="strict-origin">'
      '<style>html,body{margin:0;height:100%;background:#000}'
      'iframe{border:0;width:100%;height:100%}</style></head><body>'
      '<iframe src="$src" allow="autoplay; encrypted-media; picture-in-picture" '
      'allowfullscreen referrerpolicy="strict-origin">'
      '</iframe></body></html>';
}

final trailerPlayerBuilderProvider = Provider<TrailerPlayerBuilder>(
  (ref) => systemTrailerPlayer,
);
