import 'dart:async';

/// Runs the last of a series of calls once [delay] has passed without another
/// one, like the debounce of the search fields.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;
  void Function()? _pending;

  /// Whether an action is waiting for its turn.
  bool get isPending => _pending != null;

  void run(void Function() action) {
    _timer?.cancel();
    _pending = action;
    _timer = Timer(delay, () {
      _pending = null;
      action();
    });
  }

  /// Runs the waiting action now, for example when the field it belongs to is
  /// about to go away.
  void flush() {
    final action = _pending;
    cancel();
    action?.call();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
