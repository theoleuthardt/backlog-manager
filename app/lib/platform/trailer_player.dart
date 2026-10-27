import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the widget that plays [embedUrl] inside the app, or null on a
/// platform that has no embedded player (the trailer then plays in a window of
/// its own, see `trailer_window.dart`). Tests replace it with a placeholder, because a web view needs a
/// real window.
typedef TrailerPlayerBuilder = Widget? Function(
  BuildContext context,
  Uri embedUrl,
);

/// Whether [platform] plays trailers in the app: the web view plugin runs on
/// macOS, Windows, iOS and Android, it has no Linux implementation.
bool hasEmbeddedTrailerPlayer(TargetPlatform platform) =>
    platform == TargetPlatform.macOS ||
    platform == TargetPlatform.windows ||
    platform == TargetPlatform.iOS ||
    platform == TargetPlatform.android;

/// The player of the app: the system web view (WKWebView, WebView2, Android
/// WebView) where [hasEmbeddedTrailerPlayer] says so; Linux plays the trailer
/// in a window. Navigation stays on the YouTube hosts, every other address is
/// cancelled.
Widget? systemTrailerPlayer(BuildContext context, Uri embedUrl) {
  if (!hasEmbeddedTrailerPlayer(defaultTargetPlatform)) return null;
  return InAppWebView(
    key: const Key('trailer-webview'),
    initialData: InAppWebViewInitialData(
      data: trailerPage(embedUrl),
      baseUrl: WebUri('$trailerOrigin/'),
    ),
    shouldOverrideUrlLoading: (controller, action) async =>
        trailerNavigationAllowed(
          action.request.url,
          mainFrame: action.isForMainFrame,
        )
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL,
    initialSettings: trailerWebViewSettings(),
  );
}

/// Whether the trailer web view may load [url]: a frame inside the page
/// always, the page itself only from the app's own origin or YouTube.
bool trailerNavigationAllowed(Uri? url, {required bool mainFrame}) {
  if (!mainFrame) return true;
  final host = url?.host ?? '';
  return host == Uri.parse(trailerOrigin).host ||
      host == 'www.youtube-nocookie.com' ||
      host == 'www.youtube.com';
}

/// The settings of the trailer web view. `useShouldOverrideUrlLoading` is
/// what makes the plugin ask [trailerNavigationAllowed] at all; without it
/// every navigation goes through.
InAppWebViewSettings trailerWebViewSettings() => InAppWebViewSettings(
  useShouldOverrideUrlLoading: true,
  mediaPlaybackRequiresUserGesture: false,
  allowsInlineMediaPlayback: true,
  transparentBackground: true,
);

/// The origin the app presents to YouTube: its application id as an https
/// address. YouTube identifies an embedding client by the origin of the page
/// around the frame; a page without one gets error 153, a page that claims to
/// be youtube.com gets error 152.
const trailerOrigin = 'https://dev.theocloud.blm';

/// The page the web view loads: the embed in a frame that fills the view,
/// told which [origin] embeds it (the one the page really comes from, the
/// app's own for a page the web view builds itself).
String trailerPage(Uri embedUrl, {String origin = trailerOrigin}) {
  final withOrigin = embedUrl.replace(
    queryParameters: {
      ...embedUrl.queryParameters,
      'origin': origin,
      'widget_referrer': origin,
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
