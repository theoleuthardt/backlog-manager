import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/sse.dart';

/// [SseRunner.cancel] stopped the run.
class SseCancelled implements Exception {
  const SseCancelled();
}

/// Runs one progress stream at a time to its end and can stop it. The future
/// of [run] completes with the payload of the `done` message, fails with an
/// [ApiException] for an `error` message, with [SseCancelled] after [cancel]
/// and with [SseStreamEndedException] when the stream closes without either.
class SseRunner {
  StreamSubscription<SseEvent>? _subscription;
  Completer<Object?>? _pending;

  bool get running => _pending != null;

  Future<Object?> run(
    Stream<SseEvent> stream, {
    void Function(int processed, int total)? onProgress,
  }) {
    final pending = Completer<Object?>();
    _pending = pending;
    _subscription = stream.listen(
      (event) {
        switch (event) {
          case SseProgress(:final processed, :final total):
            onProgress?.call(processed, total);
          case SseDone(:final data):
            if (!pending.isCompleted) pending.complete(data);
          case SseError(:final message):
            if (!pending.isCompleted) {
              pending.completeError(ApiException(message));
            }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!pending.isCompleted) pending.completeError(error, stackTrace);
      },
      onDone: () {
        if (!pending.isCompleted) {
          pending.completeError(const SseStreamEndedException());
        }
      },
    );
    return pending.future.whenComplete(() {
      _subscription = null;
      _pending = null;
    });
  }

  /// Stops the running stream, which stops the request on the server.
  void cancel() {
    final pending = _pending;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const SseCancelled());
    }
  }
}
