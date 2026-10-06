import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// One decoded message of a backend progress stream.
sealed class SseEvent {
  const SseEvent();
}

/// A `progress` message: [processed] of [total] items are done.
class SseProgress extends SseEvent {
  const SseProgress(this.processed, this.total);

  final int processed;
  final int total;
}

/// The terminal `done` message; [data] is its decoded JSON payload.
class SseDone extends SseEvent {
  const SseDone(this.data);

  final Object? data;
}

/// The terminal `error` message with the backend's user-facing text.
class SseError extends SseEvent {
  const SseError(this.message);

  final String message;
}

/// The stream closed before the backend sent `done` or `error`.
class SseStreamEndedException implements Exception {
  const SseStreamEndedException();

  @override
  String toString() => 'SSE stream ended without a result';
}

/// A message of the stream carried a payload that is not what the backend
/// documents (invalid JSON, missing or non-integer progress counts).
class SseFormatException implements Exception {
  const SseFormatException(this.message);

  final String message;

  @override
  String toString() => 'SseFormatException: $message';
}

final _boundary = RegExp(r'\r\n\r\n|\n\n');
final _lineBreak = RegExp(r'\r\n|\n');

SseEvent? _decode(String raw) {
  String? event;
  final dataLines = <String>[];
  for (final line in raw.split(_lineBreak)) {
    if (line.startsWith('event:')) {
      event = _fieldValue(line, 'event:');
    } else if (line.startsWith('data:')) {
      dataLines.add(_fieldValue(line, 'data:'));
    }
  }
  final data = dataLines.join('\n');
  try {
    switch (event) {
      case 'progress':
        final json = jsonDecode(data) as Map<String, dynamic>;
        return SseProgress(json['processed'] as int, json['total'] as int);
      case 'done':
        return SseDone(jsonDecode(data));
      case 'error':
        return SseError(data);
      default:
        return null;
    }
  } on FormatException catch (error) {
    throw SseFormatException(error.message);
  } on TypeError {
    throw SseFormatException('unexpected $event payload');
  }
}

String _fieldValue(String line, String prefix) {
  final value = line.substring(prefix.length);
  return value.startsWith(' ') ? value.substring(1) : value;
}

/// Decodes a backend SSE byte stream into typed events and ends after the
/// first `done` or `error`.
///
/// Raw text is accumulated un-normalized, because a chunk boundary can land
/// inside a separator (`\r\n\r` then `\n`). Throws [SseStreamEndedException]
/// when the bytes end before a terminal event and [SseFormatException] for a
/// malformed payload.
Stream<SseEvent> parseSseEvents(Stream<List<int>> bytes) async* {
  var buffer = '';
  await for (final text in utf8.decoder.bind(bytes)) {
    buffer += text;
    var match = _boundary.firstMatch(buffer);
    while (match != null) {
      final raw = buffer.substring(0, match.start);
      buffer = buffer.substring(match.end);
      final event = raw.isEmpty ? null : _decode(raw);
      if (event != null) {
        yield event;
        if (event is! SseProgress) return;
      }
      match = _boundary.firstMatch(buffer);
    }
  }
  throw const SseStreamEndedException();
}

/// Opens a streaming endpoint through [dio] (so the Bearer token and the 401
/// rule of `createApiDio` apply) and yields its events.
///
/// The `EventSource` of a browser cannot send an Authorization header, so the
/// stream is read manually. Cancelling the subscription cancels the request
/// at once, also while the connection is still being opened, and closes the
/// connection; the backend then stops its background task. The error Dio
/// raises for the cancelled body stream is swallowed, it is the expected
/// outcome of the cancel.
Stream<SseEvent> openSse(
  Dio dio,
  String path, {
  String method = 'POST',
  Object? data,
  Map<String, Object?>? queryParameters,
}) {
  final cancelToken = CancelToken();
  StreamSubscription<SseEvent>? events;
  late final StreamController<SseEvent> controller;

  Future<void> connect() async {
    try {
      final response = await dio.request<ResponseBody>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
      events = parseSseEvents(response.data!.stream).listen(
        controller.add,
        onError: (Object error, StackTrace stackTrace) {
          if (!cancelToken.isCancelled) controller.addError(error, stackTrace);
        },
        onDone: controller.close,
      );
      if (controller.isPaused) events!.pause();
    } on Object catch (error, stackTrace) {
      if (cancelToken.isCancelled) return;
      controller.addError(error, stackTrace);
      await controller.close();
    }
  }

  controller = StreamController<SseEvent>(
    onListen: connect,
    onPause: () => events?.pause(),
    onResume: () => events?.resume(),
    onCancel: () async {
      final stopped = events?.cancel();
      if (!cancelToken.isCancelled) cancelToken.cancel();
      try {
        await stopped;
      } on DioException {
        return;
      }
    },
  );
  return controller.stream;
}
