import 'dart:io';

import 'package:backlog_manager/platform/browser_window.dart';
import 'package:backlog_manager/platform/trailer_window.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _embed = 'https://www.youtube-nocookie.com/embed/abcdefghijk';
const _watch = 'https://www.youtube.com/watch?v=abcdefghijk';

Future<({int status, String body, String type})> fetch(
  Uri url, {
  String method = 'GET',
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, url);
    final response = await request.close();
    final body = await response
        .transform(const SystemEncoding().decoder)
        .join();
    return (
      status: response.statusCode,
      body: body,
      type: response.headers.contentType?.mimeType ?? '',
    );
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('TrailerPageServer', () {
    late TrailerPageServer server;

    setUp(() async {
      server = await TrailerPageServer.start();
      addTearDown(server.close);
    });

    test('listens on the loopback address only', () {
      expect(server.address.host, '127.0.0.1');
      expect(server.address.port, greaterThan(0));
    });

    test('serves the player page of a video with its own origin', () async {
      final reply = await fetch(server.addressFor('abcdefghijk'));

      expect(reply.status, 200);
      expect(reply.type, 'text/html');
      expect(reply.body, contains('src="$_embed?'));
      expect(
        reply.body,
        contains(
          'origin=${Uri.encodeQueryComponent('http://127.0.0.1:${server.address.port}')}',
        ),
      );
      expect(reply.body, contains('<iframe'));
    });

    test('answers nothing without the secret in the path', () async {
      final good = server.addressFor('abcdefghijk');
      final wrong = good.replace(path: '/0000/abcdefghijk');

      expect((await fetch(wrong)).status, 404);
      expect((await fetch(good.replace(path: '/abcdefghijk'))).status, 404);
      expect((await fetch(good.replace(path: '/'))).status, 404);
    });

    test('answers nothing for a video id that is not one', () async {
      final good = server.addressFor('abcdefghijk');
      final secret = good.pathSegments.first;

      for (final id in [
        'short',
        'abcdefghijkl',
        'a"onload="x',
        'abc%20defghi',
      ]) {
        final reply = await fetch(good.replace(path: '/$secret/$id'));
        expect(reply.status, 404, reason: id);
      }
    });

    test('only answers a GET', () async {
      final reply = await fetch(
        server.addressFor('abcdefghijk'),
        method: 'POST',
      );

      expect(reply.status, 405);
    });

    test('owns its own pages and nothing else', () {
      expect(server.owns(server.addressFor('abcdefghijk')), isTrue);
      expect(server.owns(Uri.parse(_watch)), isFalse);
      expect(
        server.owns(Uri.parse('http://127.0.0.1:1/x/abcdefghijk')),
        isFalse,
      );
      expect(
        server.owns(
          server.addressFor('abcdefghijk').replace(path: '/other/abcdefghijk'),
        ),
        isFalse,
      );
      expect(
        server.owns(
          server.addressFor('abcdefghijk').replace(host: 'localhost'),
        ),
        isFalse,
      );
    });

    test('stops answering once it is closed', () async {
      final url = server.addressFor('abcdefghijk');
      await server.close();

      await expectLater(fetch(url), throwsA(isA<SocketException>()));
    });
  });

  group('trailerWindowOpenerProvider', () {
    test(
      'opens the page of the video in a browser window that stays on it',
      () async {
        final opened = <Uri>[];
        bool Function(Uri)? decide;
        final container = ProviderContainer(
          overrides: [
            browserWindowOpenerProvider.overrideWithValue((
              url, {
              required stays,
            }) async {
              opened.add(url);
              decide = stays;
            }),
          ],
        );
        addTearDown(container.dispose);

        await container.read(trailerWindowOpenerProvider)(
          Uri.parse(_embed),
          Uri.parse(_watch),
        );

        final server = await container.read(trailerPageServerProvider.future);
        expect(opened, [server.addressFor('abcdefghijk')]);
        expect(decide!(opened.single), isTrue);
        expect(decide!(Uri.parse(_watch)), isFalse);
        expect(decide!(Uri.parse('https://example.com/')), isFalse);
      },
    );

    test('opens the video on YouTube when the page cannot be served', () async {
      final externally = <Uri>[];
      final container = ProviderContainer(
        overrides: [
          urlOpenerProvider.overrideWithValue(externally.add),
          trailerPageServerProvider.overrideWith(
            (ref) =>
                Future<TrailerPageServer>.error(const SocketException('no')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(trailerWindowOpenerProvider)(
        Uri.parse(_embed),
        Uri.parse(_watch),
      );

      expect(externally, [Uri.parse(_watch)]);
    });

    test(
      'does not open a window for an address that is not a YouTube embed',
      () async {
        final externally = <Uri>[];
        final windows = <Uri>[];
        final container = ProviderContainer(
          overrides: [
            urlOpenerProvider.overrideWithValue(externally.add),
            browserWindowOpenerProvider.overrideWithValue((
              url, {
              required stays,
            }) async {
              windows.add(url);
            }),
          ],
        );
        addTearDown(container.dispose);

        await container.read(trailerWindowOpenerProvider)(
          Uri.parse('https://evil.example/embed/abcdefghijk'),
          Uri.parse(_watch),
        );

        expect(windows, isEmpty);
        expect(externally, [Uri.parse(_watch)]);
      },
    );
  });
}
