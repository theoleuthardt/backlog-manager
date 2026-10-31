import 'package:backlog_manager/design/focus_glide_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A focus ring that a control hands to the [FocusGlideHost] while it shows
/// the focus ([ShelfFocusRing]): the box of [context] is where the ring goes.
class GlideSource {
  GlideSource({
    required this.context,
    required this.radius,
    required this.color,
  });

  final BuildContext context;
  double radius;
  Color color;
}

class _GlideScope extends InheritedWidget {
  const _GlideScope({required this.host, required super.child});

  final FocusGlideHostState host;

  @override
  bool updateShouldNotify(_GlideScope oldWidget) => false;
}

/// One focus ring for everything below it, the focus selector of a phone or
/// handheld after DroidDeck: instead of a ring per control it glides from the
/// control that had the focus to the next one ([GlideMotion]), follows it
/// while the page scrolls, and fades out when the focus leaves. It sits above
/// the navigator, so sheets and dialogs share it, and draws over them without
/// taking a touch. The desktop has no host and keeps a ring per control.
class FocusGlideHost extends StatefulWidget {
  const FocusGlideHost({required this.child, super.key});

  final Widget child;

  /// The host above [context], or null where every control draws its own
  /// ring.
  static FocusGlideHostState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlideScope>()?.host;

  @override
  State<FocusGlideHost> createState() => FocusGlideHostState();
}

/// How long the ring keeps following its control after a change at most, and
/// how long the control has to stand still before it stops earlier.
const _trackLimit = 2.0;
const _trackSettle = 0.45;
const _stillTime = 0.12;
const _colorTime = 0.16;
const _strokeWidth = 2.0;

/// The step of the first frame after the ring starts to move, which the
/// ticker reports as no time at all.
const _firstFrame = 1 / 60;

class FocusGlideHostState extends State<FocusGlideHost>
    with SingleTickerProviderStateMixin {
  final _motion = GlideMotion();
  final _hot = <GlideSource>[];
  final _frames = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_tick);

  GlideSource? _target;
  GlideSource? _shown;
  Rect? _seen;
  Duration _last = Duration.zero;
  double _sinceMove = double.infinity;
  double _tracked = 0;
  double _still = 0;
  bool _retargetScheduled = false;

  Color _color = Colors.transparent;
  Color _fromColor = Colors.transparent;
  Color _toColor = Colors.transparent;
  double _colorProgress = 1;

  /// The ring as it is drawn now, in the coordinates of the host, or null
  /// while it is hidden.
  @visibleForTesting
  Rect? get ringRect => _motion.visible ? _motion.rect : null;

  /// [source] shows the focus now; the ring goes there.
  void claim(GlideSource source) {
    _hot
      ..remove(source)
      ..add(source);
    _scheduleRetarget();
  }

  /// [source] no longer shows the focus.
  void release(GlideSource source) {
    if (_hot.remove(source)) _scheduleRetarget();
  }

  void _scheduleRetarget() {
    if (_retargetScheduled) return;
    _retargetScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _retargetScheduled = false;
        if (mounted) _retarget();
      })
      ..ensureVisualUpdate();
  }

  bool get _reducedMotion => MediaQuery.of(context).disableAnimations;

  void _retarget() {
    _target = _hot.isEmpty ? null : _hot.last;
    if (_target == null) {
      _shown = null;
      if (_reducedMotion) {
        _motion.snapHidden();
        _frames.value++;
      } else {
        _motion.hide();
        _run();
      }
      return;
    }
    _apply();
    if (!_reducedMotion) _run();
  }

  /// Aims the ring at the box of the target, or keeps it where it is while
  /// the target is out of sight (the page is still scrolling to it).
  void _apply() {
    final target = _target;
    if (target == null) return;
    final bounds = _boundsOf(target);
    if (bounds == null) return;
    if (_reducedMotion) {
      _setColor(target.color, at: true);
      _shown = target;
      _seen = bounds;
      _motion.snap(bounds, radius: target.radius);
      _frames.value++;
      return;
    }
    if (target != _shown) {
      _setColor(target.color, at: !_motion.visible);
      if (_motion.visible) {
        _motion.moveTo(
          bounds,
          radius: target.radius,
          elapsedSinceLastMove: _sinceMove,
        );
      } else {
        _motion.show(bounds, radius: target.radius);
      }
      _shown = target;
      _seen = bounds;
      _sinceMove = 0;
      _still = 0;
    } else if (bounds != _seen) {
      _seen = bounds;
      _still = 0;
      _motion.follow(bounds);
    }
  }

  void _setColor(Color color, {required bool at}) {
    if (at) {
      _color = color;
      _toColor = color;
      _colorProgress = 1;
    } else if (color != _toColor) {
      _fromColor = _color;
      _toColor = color;
      _colorProgress = 0;
    }
  }

  void _run() {
    _tracked = 0;
    _still = 0;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = elapsed == Duration.zero
        ? _firstFrame
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    _sinceMove += dt;
    _tracked += dt;
    _still += dt;
    _apply();
    if (_target != null && _target != _shown && _tracked >= _trackLimit) {
      _target = null;
      _shown = null;
      _motion.hide();
    }
    _motion.step(dt);
    if (_colorProgress < 1) {
      _colorProgress = (_colorProgress + dt / _colorTime).clamp(0.0, 1.0);
      _color = Color.lerp(_fromColor, _toColor, _colorProgress)!;
    }
    _frames.value++;
    final tracking =
        _target != null &&
        _tracked < _trackLimit &&
        (_tracked < _trackSettle || _still < _stillTime);
    if (!_motion.animating && _colorProgress >= 1 && !tracking) {
      _ticker.stop();
    }
  }

  Rect? _boundsOf(GlideSource source) {
    final element = source.context as Element;
    if (!element.mounted) return null;
    final box = source.context.findRenderObject();
    final hostBox = context.findRenderObject();
    if (box is! RenderBox ||
        hostBox is! RenderBox ||
        !box.attached ||
        !box.hasSize) {
      return null;
    }
    var rect = MatrixUtils.transformRect(
      box.getTransformTo(hostBox),
      Offset.zero & box.size,
    );
    final viewport = Scrollable.maybeOf(source.context)?.context
        .findRenderObject();
    if (viewport is RenderBox && viewport.attached && viewport.hasSize) {
      rect = rect.intersect(
        MatrixUtils.transformRect(
          viewport.getTransformTo(hostBox),
          Offset.zero & viewport.size,
        ),
      );
    }
    return rect.width < 1 || rect.height < 1 ? null : rect;
  }

  bool _onScroll(ScrollNotification notification) {
    if (_target == null) return false;
    if (_reducedMotion) {
      _apply();
    } else {
      _run();
    }
    return false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlideScope(
      host: this,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomPaint(
          foregroundPainter: _GlidePainter(this),
          child: widget.child,
        ),
      ),
    );
  }
}

class _GlidePainter extends CustomPainter {
  _GlidePainter(this.host) : super(repaint: host._frames);

  final FocusGlideHostState host;

  @override
  void paint(Canvas canvas, Size size) {
    final motion = host._motion;
    if (!motion.visible || motion.opacity <= 0.01) return;
    final rect = motion.rect;
    final color = host._color;
    final solid = motion.solid;
    if (solid > 0.01) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(motion.corner)),
        Paint()..color = color.withValues(alpha: motion.opacity * solid),
      );
    }
    if (solid < 0.99) {
      final inset = rect.deflate(_strokeWidth / 2);
      if (inset.width <= 0 || inset.height <= 0) return;
      final radius = (motion.corner - _strokeWidth / 2).clamp(
        0.0,
        inset.shortestSide / 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(inset, Radius.circular(radius)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..color = color.withValues(alpha: motion.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_GlidePainter oldDelegate) => oldDelegate.host != host;
}
