import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:backlog_manager/platform/browser_window.dart';
import 'package:backlog_manager/platform/trailer_player.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// A small web server on the loopback address that serves the page of the
/// trailer player. YouTube only plays an embed in a page that has an origin
/// (without one the player shows error 153), and a window that can only be
/// told an address cannot be given a page of its own, so the page comes from
/// here: `http://127.0.0.1:<port>/<secret>/<video id>`. The secret, 16 random
/// bytes, keeps other programs and web pages from asking for it, and the
/// server only answers a GET for a well formed video id.
class TrailerPageServer {
  TrailerPageServer._(this._server, this._secret);

  final HttpServer _server;
  final String _secret;

  /// Starts the server on a free port of the loopback address.
  static Future<TrailerPageServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final secret = [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final result = TrailerPageServer._(server, secret);
    server.listen((request) => unawaited(result._answer(request)));
    return result;
  }

  Uri get address => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port);

  /// The address of the player page of [videoId].
  Uri addressFor(String videoId) => address.replace(path: '/$_secret/$videoId');

  /// Whether [url] is a page of this server.
  bool owns(Uri url) =>
      url.scheme == 'http' &&
      url.host == '127.0.0.1' &&
      url.port == _server.port &&
      url.pathSegments.length == 2 &&
      url.pathSegments.first == _secret;

  Future<void> close() => _server.close(force: true);

  Future<void> _answer(HttpRequest request) async {
    final response = request.response;
    final segments = request.uri.pathSegments;
    if (request.method != 'GET') {
      response.statusCode = HttpStatus.methodNotAllowed;
    } else if (segments.length != 2 ||
        segments.first != _secret ||
        !_videoId.hasMatch(segments.last)) {
      response.statusCode = HttpStatus.notFound;
    } else {
      response
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-store')
        ..write(
          trailerPage(
            Uri.parse(
              'https://www.youtube-nocookie.com/embed/${segments.last}',
            ),
            origin: address.origin,
          ),
        );
    }
    await response.close();
  }
}

/// The page server of the trailer window, started the first time a trailer
/// plays in a window and stopped with the app. A failure is not retried: the
/// trailer opens on YouTube instead.
final trailerPageServerProvider = FutureProvider<TrailerPageServer>((
  ref,
) async {
  final server = await TrailerPageServer.start();
  ref.onDispose(() => unawaited(server.close()));
  return server;
}, retry: (retryCount, error) => null);

/// Plays the trailer with the embed address [embedUrl] in a browser window;
/// [watchUrl] is where it opens instead when that cannot be done.
typedef TrailerWindowOpener = Future<void> Function(Uri embedUrl, Uri watchUrl);

/// The trailer window for platforms without an embedded player: the player
/// page of the video from the loopback server, in a browser window that stays
/// on that page (a link of the player, "Watch on YouTube" for one, opens in
/// the system browser). Anything that is not a YouTube embed, or any failure,
/// opens the video on YouTube in the system browser. Tests replace it.
final trailerWindowOpenerProvider = Provider<TrailerWindowOpener>(
  (ref) => (embedUrl, watchUrl) async {
    final host = embedUrl.host;
    final isEmbed =
        (host == 'www.youtube-nocookie.com' || host == 'www.youtube.com') &&
        embedUrl.pathSegments.length == 2 &&
        embedUrl.pathSegments.first == 'embed' &&
        _videoId.hasMatch(embedUrl.pathSegments.last);
    if (!isEmbed) {
      ref.read(urlOpenerProvider)(watchUrl);
      return;
    }
    try {
      final server = await ref.read(trailerPageServerProvider.future);
      await ref.read(browserWindowOpenerProvider)(
        server.addressFor(embedUrl.pathSegments.last),
        stays: server.owns,
      );
    } on Object {
      ref.read(urlOpenerProvider)(watchUrl);
    }
  },
);
