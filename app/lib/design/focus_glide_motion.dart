/// The motion of the gliding focus ring of a touch screen ([FocusGlideHost]),
/// after the focus selector of DroidDeck: every edge of the ring is its own
/// spring, so the ring stretches toward the next control and settles there,
/// and a far jump shrinks it to a dot that flies across. Pure arithmetic over
/// a clock that [GlideMotion.step] advances, so it is tested frame by frame.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';

/// A damped spring: [damping] 1 is critical, below it the edge overshoots.
class GlideSpring {
  const GlideSpring(this.damping, this.stiffness);

  final double damping;
  final double stiffness;
}

const _lead = GlideSpring(0.62, 700);
const _trail = GlideSpring(0.78, 360);
const _sideSpring = GlideSpring(0.7, 520);
const _held = GlideSpring(0.9, 900);
const _appear = GlideSpring(0.6, 700);
const _follow = GlideSpring(1, 2400);
const _opening = GlideSpring(0.7, 750);
const _cornerSpring = GlideSpring(0.8, 500);

/// The delay of the trailing edge, in seconds.
const _trailDelay = 0.03;

/// Moves closer together than this (seconds) come from a held D-pad.
const repeatInterval = 0.18;

/// How far (logical pixels) a move goes before the ring flies as a dot.
const farJump = 360.0;

/// How long after a move a moving target still uses the springs of the move.
const _settleTime = 0.45;

const _fadeIn = 0.14;
const _fadeOut = 0.14;
const _hideDelay = 0.06;
const _grow = 3.0;
const _dotRadius = 6.0;
const _shrinkTime = 0.09;
const _solidOut = 0.15;

enum _Phase { springs, shrink, fly }

/// The ring: its [rect], [corner] radius, [opacity] and [solid] (how much of
/// it is a filled dot during a far jump).
class GlideMotion {
  final _edges = List<double>.filled(4, 0);
  final _velocity = List<double>.filled(4, 0);
  final _target = List<double>.filled(4, 0);
  final _springs = List<GlideSpring>.filled(4, _follow);
  final _startAt = List<double>.filled(4, 0);

  double _now = 0;
  double _movedAt = -1;

  double _corner = 0;
  double _cornerVelocity = 0;
  double _cornerTarget = 0;

  double _opacity = 0;
  double _opacityTarget = 0;
  double _hideAt = 0;

  double _solid = 0;
  double _solidTarget = 0;
  double _solidRate = 1 / 0.08;

  _Phase _phase = _Phase.springs;
  double _phaseStart = 0;
  double _travel = 0;
  Offset _from = Offset.zero;
  List<double> _shrinkFrom = const [0, 0, 0, 0];
  Rect _destination = Rect.zero;
  double _destinationRadius = 0;

  Rect get rect => Rect.fromLTRB(_edges[0], _edges[1], _edges[2], _edges[3]);
  double get corner => _corner;
  double get opacity => _opacity;
  double get solid => _solid;
  bool get visible => _opacity > 0.01 || _opacityTarget > 0;

  /// Whether a frame would change anything.
  bool get animating {
    if (_phase != _Phase.springs) return true;
    if (_opacity != _opacityTarget || _solid != _solidTarget) return true;
    if ((_corner - _cornerTarget).abs() > 0.3 || _cornerVelocity.abs() > 3) {
      return true;
    }
    for (var i = 0; i < 4; i++) {
      if (_now < _startAt[i]) return true;
      if ((_edges[i] - _target[i]).abs() > 0.3 || _velocity[i].abs() > 3) {
        return true;
      }
    }
    return false;
  }

  /// The ring appears at [target], growing in from a little larger.
  void show(Rect target, {required double radius}) {
    _phase = _Phase.springs;
    _setEdges(target.inflate(_grow));
    _velocity.fillRange(0, 4, 0);
    _aim(target, List.filled(4, _appear), const [0, 0, 0, 0]);
    _corner = radius;
    _cornerTarget = radius;
    _cornerVelocity = 0;
    _solid = 0;
    _solidTarget = 0;
    _opacityTarget = 1;
    _hideAt = 0;
    _movedAt = _now;
  }

  /// The ring goes from where it is to [target]: the edge in the direction
  /// of the move leads, the opposite one trails. [elapsedSinceLastMove]
  /// (seconds) tells a held D-pad, whose moves keep all edges together, from
  /// single steps; a single step farther than [farJump] flies as a dot.
  void moveTo(
    Rect target, {
    required double radius,
    required double elapsedSinceLastMove,
  }) {
    if (!visible) {
      show(target, radius: radius);
      return;
    }
    _opacityTarget = 1;
    _hideAt = 0;
    _movedAt = _now;
    final here = rect.center;
    final dx = target.center.dx - here.dx;
    final dy = target.center.dy - here.dy;
    final held = elapsedSinceLastMove < repeatInterval;
    if (!held && math.sqrt(dx * dx + dy * dy) > farJump) {
      _startDroplet(target, radius, math.sqrt(dx * dx + dy * dy));
      return;
    }
    _phase = _Phase.springs;
    _solidTarget = 0;
    _solidRate = 1 / 0.12;
    _cornerTarget = radius;
    if (held) {
      _aim(target, List.filled(4, _held), const [0, 0, 0, 0]);
      return;
    }
    final horizontal = dx.abs() >= dy.abs();
    final lead = horizontal ? (dx >= 0 ? 2 : 0) : (dy >= 0 ? 3 : 1);
    final trail = (lead + 2) % 4;
    _aim(
      target,
      [
        for (var i = 0; i < 4; i++)
          i == lead ? _lead : (i == trail ? _trail : _sideSpring),
      ],
      [for (var i = 0; i < 4; i++) i == trail ? _trailDelay : 0],
    );
  }

  /// The target moved under the ring (the page scrolled): shortly after a
  /// move the ring keeps the springs of the move, later it follows firmly.
  void follow(Rect target) {
    if (_phase != _Phase.springs) {
      _destination = target;
      return;
    }
    final fresh = _now - _movedAt < _settleTime;
    for (var i = 0; i < 4; i++) {
      _target[i] = _side(target, i);
      if (!fresh) _springs[i] = _follow;
    }
  }

  /// The focus left: the ring fades out after a moment.
  void hide() {
    if (_opacityTarget == 0) return;
    _opacityTarget = 0;
    _hideAt = _now + _hideDelay;
  }

  /// The ring at [target] at once (the system asks for less motion).
  void snap(Rect target, {required double radius}) {
    _phase = _Phase.springs;
    _setEdges(target);
    _velocity.fillRange(0, 4, 0);
    _target.setAll(0, _edgesOf(target));
    _startAt.fillRange(0, 4, _now);
    _corner = radius;
    _cornerTarget = radius;
    _cornerVelocity = 0;
    _opacity = 1;
    _opacityTarget = 1;
    _solid = 0;
    _solidTarget = 0;
  }

  /// The ring gone at once.
  void snapHidden() {
    _phase = _Phase.springs;
    _opacity = 0;
    _opacityTarget = 0;
    _solid = 0;
    _solidTarget = 0;
  }

  /// Advances the clock by [dt] seconds.
  void step(double dt) {
    _now += dt;
    switch (_phase) {
      case _Phase.shrink:
        final t = ((_now - _phaseStart) / _shrinkTime).clamp(0.0, 1.0);
        final dot = _edgesOf(_dot(_from));
        for (var i = 0; i < 4; i++) {
          _edges[i] = lerpDouble(_shrinkFrom[i], dot[i], t)!;
        }
        _corner = lerpDouble(_corner, _dotRadius, t)!;
        if (t >= 1) {
          _phase = _Phase.fly;
          _phaseStart = _now;
        }
      case _Phase.fly:
        final t = ((_now - _phaseStart) / _travel).clamp(0.0, 1.0);
        final p = _fastOutSlowIn(t);
        final center = Offset.lerp(_from, _destination.center, p)!;
        _setEdges(_dot(center));
        if (p >= 0.78) _open();
      case _Phase.springs:
        for (var i = 0; i < 4; i++) {
          if (_now >= _startAt[i]) {
            final (x, v) = _spring(
              _edges[i],
              _velocity[i],
              _target[i],
              _springs[i],
              dt,
            );
            _edges[i] = x;
            _velocity[i] = v;
          }
        }
        final (c, cv) = _spring(
          _corner,
          _cornerVelocity,
          _cornerTarget,
          _cornerSpring,
          dt,
        );
        _corner = c;
        _cornerVelocity = cv;
    }
    _solid = _toward(_solid, _solidTarget, _solidRate * dt);
    if (_opacityTarget > _opacity) {
      _opacity = _toward(_opacity, 1, dt / _fadeIn);
    } else if (_opacityTarget < _opacity && _now >= _hideAt) {
      _opacity = _toward(_opacity, 0, dt / _fadeOut);
    }
  }

  void _startDroplet(Rect target, double radius, double distance) {
    _phase = _Phase.shrink;
    _phaseStart = _now;
    _from = rect.center;
    _shrinkFrom = List.of(_edges);
    _velocity.fillRange(0, 4, 0);
    _destination = target;
    _destinationRadius = radius;
    _travel = (180 + distance * 0.12).clamp(220, 380) / 1000;
    _solidTarget = 1;
    _solidRate = 1 / 0.08;
  }

  void _open() {
    _phase = _Phase.springs;
    _aim(_destination, List.filled(4, _opening), const [0, 0, 0, 0]);
    _cornerTarget = _destinationRadius;
    _solidTarget = 0;
    _solidRate = 1 / _solidOut;
  }

  void _aim(Rect target, List<GlideSpring> springs, List<double> delays) {
    for (var i = 0; i < 4; i++) {
      _target[i] = _side(target, i);
      _springs[i] = springs[i];
      _startAt[i] = _now + delays[i];
    }
  }

  void _setEdges(Rect r) => _edges.setAll(0, _edgesOf(r));

  static List<double> _edgesOf(Rect r) => [r.left, r.top, r.right, r.bottom];

  static double _side(Rect r, int i) => switch (i) {
    0 => r.left,
    1 => r.top,
    2 => r.right,
    _ => r.bottom,
  };

  static Rect _dot(Offset center) =>
      Rect.fromCircle(center: center, radius: _dotRadius);

  static double _toward(double value, double target, double step) =>
      value < target
      ? math.min(target, value + step)
      : math.max(target, value - step);

  static double _fastOutSlowIn(double t) => Curves.fastOutSlowIn.transform(t);

  /// One step of a damped spring in sub-steps of 4 ms, settled to its target
  /// once it is close and slow.
  static (double, double) _spring(
    double x,
    double v,
    double target,
    GlideSpring spring,
    double dt,
  ) {
    final k = spring.stiffness;
    final c = 2 * spring.damping * math.sqrt(k);
    var left = dt;
    while (left > 0) {
      final h = math.min(left, 0.004);
      v += (-k * (x - target) - c * v) * h;
      x += v * h;
      left -= h;
    }
    if ((x - target).abs() < 0.3 && v.abs() < 3) return (target, 0);
    return (x, v);
  }
}
