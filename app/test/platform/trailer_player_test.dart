import 'package:backlog_manager/platform/trailer_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trailer navigation', () {
    for (final host in [
      'dev.theocloud.blm',
      'www.youtube-nocookie.com',
      'www.youtube.com',
    ]) {
      test('stays on $host', () {
        expect(
          trailerNavigationAllowed(
            Uri.parse('https://$host/x'),
            mainFrame: true,
          ),
          isTrue,
        );
      });
    }

    test('cancels a page of another host', () {
      expect(
        trailerNavigationAllowed(
          Uri.parse('https://example.com/'),
          mainFrame: true,
        ),
        isFalse,
      );
      expect(trailerNavigationAllowed(null, mainFrame: true), isFalse);
    });

    test('lets the web view open its blank start page', () {
      expect(
        trailerNavigationAllowed(Uri.parse('about:blank'), mainFrame: true),
        isTrue,
      );
    });

    test('lets the frames inside the page load', () {
      expect(
        trailerNavigationAllowed(
          Uri.parse('https://example.com/ad'),
          mainFrame: false,
        ),
        isTrue,
      );
    });

    test('asks the app before every navigation', () {
      expect(trailerWebViewSettings().useShouldOverrideUrlLoading, isTrue);
    });
  });

  group('hasEmbeddedTrailerPlayer', () {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.iOS,
      TargetPlatform.android,
    ]) {
      test('plays in the app on ${platform.name}', () {
        expect(hasEmbeddedTrailerPlayer(platform), isTrue);
      });
    }

    test('leaves Linux to the trailer window', () {
      expect(hasEmbeddedTrailerPlayer(TargetPlatform.linux), isFalse);
    });
  });

  group('trailerPage', () {
    final page = trailerPage(
      Uri.parse('https://www.youtube-nocookie.com/embed/abc123?autoplay=1'),
    );

    test('puts the embed in a frame that fills the page', () {
      expect(
        page,
        contains('src="https://www.youtube-nocookie.com/embed/abc123?'),
      );
      expect(page, contains('autoplay=1'));
      expect(page, contains('<iframe'));
      expect(page, contains('allowfullscreen'));
    });

    test('names the app as the embedding origin, not YouTube itself', () {
      expect(trailerOrigin, isNot(contains('youtube')));
      expect(page, contains('referrerpolicy="strict-origin"'));
      expect(
        page,
        contains('origin=${Uri.encodeQueryComponent(trailerOrigin)}'),
      );
    });

    test('names another origin when the page comes from one', () {
      final local = trailerPage(
        Uri.parse('https://www.youtube-nocookie.com/embed/abc123'),
        origin: 'http://127.0.0.1:4000',
      );

      expect(
        local,
        contains('origin=${Uri.encodeQueryComponent('http://127.0.0.1:4000')}'),
      );
      expect(local, isNot(contains(Uri.encodeQueryComponent(trailerOrigin))));
    });

    test('escapes the address so it cannot leave the attribute', () {
      final hostile = trailerPage(
        Uri.parse('https://www.youtube.com/embed/a"onload="x'),
      );

      expect(hostile, isNot(contains('"onload="x')));
    });
  });
}
