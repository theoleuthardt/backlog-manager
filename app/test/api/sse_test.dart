import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:backlog_manager/api/sse.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const recordedStream =
    'event: progress\r\ndata: {"processed": 1, "total": 3}\r\n\r\n'
    'event: progress\r\ndata: {"processed": 2, "total": 3}\r\n\r\n'
    'event: progress\r\ndata: {"processed": 3, "total": 3}\r\n\r\n'
    'event: done\r\ndata: {"imported": 3, "skipped": 0}\r\n\r\n';

Stream<List<int>> chunked(String text, int size) async* {
  final bytes = utf8.encode(text);
  for (var i = 0; i < bytes.length; i += size) {
    yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
  }
}

class StreamAdapter implements HttpClientAdapter {
  StreamAdapter(this.body, {this.status = 200, this.delay});

  final Stream<List<int>> body;
  final int status;
  final Future<void>? delay;
  Future<void>? cancelFuture;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    this.cancelFuture = cancelFuture;
    await delay;
    return ResponseBody(
      body.map(Uint8List.fromList),
      status,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('parseSseEvents', () {
    test(
      'delivers progress then done in order for a recorded stream',
      () async {
        final events = await parseSseEvents(chunked(recordedStream, 4096))
            .toList();

        expect(events, hasLength(4));
        expect(events.take(3).cast<SseProgress>().map((e) => e.processed), [
          1,
          2,
          3,
        ]);
        expect(
          events[0],
          isA<SseProgress>().having((e) => e.total, 'total', 3),
        );
        expect(
          events[3],
          isA<SseDone>().having((e) => e.data, 'data', {
            'imported': 3,
            'skipped': 0,
          }),
        );
      },
    );

    test('handles chunks of any size, including one byte at a time', () async {
      for (final size in [1, 2, 3, 7, 16]) {
        final events = await parseSseEvents(chunked(recordedStream, size))
            .toList();

        expect(events, hasLength(4), reason: 'chunk size $size');
        expect(events.last, isA<SseDone>(), reason: 'chunk size $size');
      }
    });

    test('recognises a separator split across chunks', () async {
      final events = await parseSseEvents(
        Stream.fromIterable([
          utf8.encode(
            'event: progress\r\ndata: {"processed":1,"total":2}\r\n\r',
          ),
          utf8.encode('\nevent: done\ndata: {}\n\n'),
        ]),
      ).toList();

      expect(events, [isA<SseProgress>(), isA<SseDone>()]);
    });

    test('accepts LF line endings and fields without a space', () async {
      final events = await parseSseEvents(
        Stream.value(
          utf8.encode(
            'event:progress\ndata:{"processed":1,"total":1}\n\nevent:done\ndata:null\n\n',
          ),
        ),
      ).toList();

      expect(events, [isA<SseProgress>(), isA<SseDone>()]);
    });

    test('keeps multi-byte characters that are split across chunks', () async {
      final bytes = utf8.encode('event: error\ndata: Überlauf für 日本\n\n');
      final events = await parseSseEvents(
        Stream.fromIterable([
          for (final b in bytes) [b],
        ]),
      ).toList();

      expect(
        events.single,
        isA<SseError>().having((e) => e.message, 'message', 'Überlauf für 日本'),
      );
    });

    test('ends after an error event with its message', () async {
      final events = await parseSseEvents(
        Stream.value(
          utf8.encode(
            'event: progress\ndata: {"processed":1,"total":2}\n\nevent: error\ndata: Steam is unreachable\n\nevent: progress\ndata: {"processed":2,"total":2}\n\n',
          ),
        ),
      ).toList();

      expect(events, hasLength(2));
      expect(
        events.last,
        isA<SseError>().having(
          (e) => e.message,
          'message',
          'Steam is unreachable',
        ),
      );
    });

    test('throws when the stream ends without done or error', () async {
      final stream = parseSseEvents(
        Stream.value(
          utf8.encode('event: progress\ndata: {"processed":1,"total":2}\n\n'),
        ),
      );

      await expectLater(
        stream.toList(),
        throwsA(isA<SseStreamEndedException>()),
      );
    });

    for (final payload in [
      'event: progress\ndata: not json\n\n',
      'event: progress\ndata: {"processed":"1","total":2}\n\n',
      'event: progress\ndata: {"total":2}\n\n',
      'event: progress\ndata: [1]\n\n',
      'event: done\ndata: {broken\n\n',
    ]) {
      test('rejects the malformed payload ${jsonEncode(payload)}', () async {
        final stream = parseSseEvents(Stream.value(utf8.encode(payload)));

        await expectLater(stream.toList(), throwsA(isA<SseFormatException>()));
      });
    }

    test('ignores comments and unknown events', () async {
      final events = await parseSseEvents(
        Stream.value(
          utf8.encode(
            ': keep-alive\n\nevent: ping\ndata: x\n\nevent: done\ndata: 1\n\n',
          ),
        ),
      ).toList();

      expect(events, [isA<SseDone>().having((e) => e.data, 'data', 1)]);
    });
  });

  group('openSse', () {
    test('posts to the path and streams the typed events', () async {
      final adapter = StreamAdapter(chunked(recordedStream, 10));
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = adapter;

      final events = await openSse(
        dio,
        '/api/user/steam/import-stream',
      ).toList();

      expect(adapter.request!.method, 'POST');
      expect(adapter.request!.path, '/api/user/steam/import-stream');
      expect(adapter.request!.headers['Accept'], 'text/event-stream');
      expect(events.last, isA<SseDone>());
    });

    test('cancelling the consumer closes the connection', () async {
      final controller = StreamController<List<int>>();
      final adapter = StreamAdapter(controller.stream);
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = adapter;

      final received = Completer<SseEvent>();
      final subscription = openSse(dio, '/stream').listen(received.complete);
      controller.add(
        utf8.encode('event: progress\ndata: {"processed":1,"total":9}\n\n'),
      );
      await received.future;

      var closed = false;
      unawaited(adapter.cancelFuture!.then((_) => closed = true));
      await subscription.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(closed, isTrue);
      await controller.close();
    });

    test(
      'cancelling before the response arrives cancels the request',
      () async {
        final gate = Completer<void>();
        final adapter = StreamAdapter(const Stream.empty(), delay: gate.future);
        final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
          ..httpClientAdapter = adapter;

        final subscription = openSse(dio, '/stream').listen((_) {});
        await Future<void>.delayed(Duration.zero);
        var closed = false;
        unawaited(adapter.cancelFuture!.then((_) => closed = true));

        await subscription.cancel();
        gate.complete();
        await Future<void>.delayed(Duration.zero);

        expect(closed, isTrue);
      },
    );

    test('surfaces a failed request as a DioException', () async {
      final adapter = StreamAdapter(
        Stream.value(utf8.encode('{"detail":"Not authenticated"}')),
        status: 401,
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = adapter;

      await expectLater(
        openSse(dio, '/stream').toList(),
        throwsA(isA<DioException>()),
      );
    });
  });
}
