import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// A view of a looping [source] that notifies at most [framesPerSecond] times
/// per second, however fast the display runs. The slow decorative motions (the
/// sky, the glow of a cover) do not need more, and every notification costs a
/// repaint of the layers below them. A step a tenth short of one frame keeps
/// display jitter from skipping a whole frame.
class ThrottledClock extends ChangeNotifier implements ValueListenable<double> {
  ThrottledClock(
    this._source, {
    required Duration period,
    int framesPerSecond = 30,
  }) : _step = 0.9 / framesPerSecond / (period.inMicroseconds / 1e6),
       _value = _source.value {
    _source.addListener(_onTick);
  }

  final Animation<double> _source;
  final double _step;
  double _value;

  @override
  double get value => _value;

  void _onTick() {
    if ((_source.value - _value).abs() < _step) return;
    _value = _source.value;
    notifyListeners();
  }

  @override
  void dispose() {
    _source.removeListener(_onTick);
    super.dispose();
  }
}
