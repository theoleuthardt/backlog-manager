import 'package:backlog_manager/design/frame_strain.dart';
import 'package:flutter_test/flutter_test.dart';

const _smooth = Duration(milliseconds: 8);
const _slow = Duration(milliseconds: 40);

/// Feeds [count] frames of [length] and returns whether the last one found
/// the device strained.
bool _feed(FrameStrain strain, int count, Duration length) {
  var strained = false;
  for (var i = 0; i < count; i++) {
    strained = strain.add(length);
  }
  return strained;
}

void main() {
  test('smooth frames never count as strain', () {
    final strain = FrameStrain();

    expect(_feed(strain, 2000, _smooth), isFalse);
  });

  test('slow frames right after the start are left out', () {
    final strain = FrameStrain();

    expect(_feed(strain, strain.warmUp, _slow), isFalse);
    expect(_feed(strain, 2 * strain.window, _smooth), isFalse);
  });

  test('two windows in a row with many slow frames are strain', () {
    final strain = FrameStrain();
    _feed(strain, strain.warmUp, _smooth);

    expect(_feed(strain, strain.window, _slow), isFalse, reason: 'one only');
    expect(_feed(strain, strain.window, _slow), isTrue);
  });

  test('a smooth window in between starts the count again', () {
    final strain = FrameStrain();
    _feed(strain, strain.warmUp, _smooth);

    _feed(strain, strain.window, _slow);
    _feed(strain, strain.window, _smooth);

    expect(_feed(strain, strain.window, _slow), isFalse);
  });

  test('a few slow frames in a window are no strain', () {
    final strain = FrameStrain();
    _feed(strain, strain.warmUp, _smooth);

    for (var round = 0; round < 4; round++) {
      _feed(strain, strain.window ~/ 10, _slow);
      _feed(strain, strain.window - strain.window ~/ 10, _smooth);
    }

    expect(strain.strained, isFalse);
  });

  test('stays strained once it was', () {
    final strain = FrameStrain();
    _feed(strain, strain.warmUp, _smooth);
    _feed(strain, 2 * strain.window, _slow);

    expect(_feed(strain, 1000, _smooth), isTrue);
  });
}
