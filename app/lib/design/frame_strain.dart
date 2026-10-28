/// Tells from the frame times whether the device cannot keep up with the full
/// effects. The first [warmUp] frames are left out (the shaders of a new
/// screen compile there); after that every [window] frames are a round, and a
/// round is slow when at least [limit] of its frames took longer than
/// [budget]. Two slow rounds in a row are strain, which stays for the session:
/// one slow round can be a page that loads, and lighter effects that switch
/// back on would only drop frames again.
class FrameStrain {
  FrameStrain({
    this.budget = const Duration(milliseconds: 25),
    this.window = 120,
    this.limit = 0.25,
    this.warmUp = 180,
  });

  final Duration budget;
  final int window;
  final double limit;
  final int warmUp;

  var _seen = 0;
  var _inRound = 0;
  var _slowInRound = 0;
  var _slowRounds = 0;
  var _strained = false;

  bool get strained => _strained;

  /// Takes the time of one frame (the longer of its build and raster time)
  /// and returns [strained].
  bool add(Duration frame) {
    if (_strained) return true;
    _seen++;
    if (_seen <= warmUp) return false;
    _inRound++;
    if (frame > budget) _slowInRound++;
    if (_inRound < window) return false;
    final slow = _slowInRound >= window * limit;
    _slowRounds = slow ? _slowRounds + 1 : 0;
    _inRound = 0;
    _slowInRound = 0;
    _strained = _slowRounds >= 2;
    return _strained;
  }
}
