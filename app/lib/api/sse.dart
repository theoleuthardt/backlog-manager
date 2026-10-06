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

const _terminator = r'(?:\r\n|\n|\r(?!\n|$))';
final _boundary = RegExp('$_terminator$_terminator');
final _lineBreak = RegExp(r'\r\n|\n|\r');

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

(List<String>, String) _splitMessages(String buffer) {
  final messages = <String>[];
  var match = _boundary.firstMatch(buffer);
  while (match != null) {
    final raw = buffer.substring(0, match.start);
    if (raw.isNotEmpty) messages.add(raw);
    buffer = buffer.substring(match.end);
    match = _boundary.firstMatch(buffer);
  }
  return (messages, buffer);
}

Iterable<SseEvent> _decodeAll(List<String> messages) sync* {
  for (final raw in messages) {
    final event = _decode(raw);
    if (event != null) yield event;
  }
}

/// Decodes a backend SSE byte stream into typed events and ends after the
/// first `done` or `error`.
///
/// Lines end with CRLF, LF or CR, also mixed. Raw text is accumulated
/// un-normalized, because a chunk boundary can land inside a separator
/// (`\r\n\r` then `\n`); for that reason a CR at the very end of the buffer is
/// not a line end yet, it may be the first half of a CRLF, and counts as one
/// once the stream closes. Throws [SseStreamEndedException] when the bytes end
/// before a terminal event and [SseFormatException] for a malformed payload.
Stream<SseEvent> parseSseEvents(Stream<List<int>> bytes) async* {
  var buffer = '';
  await for (final text in utf8.decoder.bind(bytes)) {
    buffer += text;
    final (messages, rest) = _splitMessages(buffer);
    buffer = rest;
    for (final event in _decodeAll(messages)) {
      yield event;
      if (event is! SseProgress) return;
    }
  }
  if (buffer.endsWith('\r')) {
    for (final event in _decodeAll(_splitMessages('$buffer\n').$1)) {
      yield event;
      if (event is! SseProgress) return;
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
