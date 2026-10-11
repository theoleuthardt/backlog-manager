import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/freaky_orbs.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One star of the sky; [halo] is the radius of its soft glow, 0 for none.
class AtmosphereStar {
  const AtmosphereStar({
    required this.center,
    required this.radius,
    required this.color,
    this.halo = 0,
    this.haloColor = const Color(0x00000000),
  });

  final Offset center;
  final double radius;
  final Color color;
  final double halo;
  final Color haloColor;
}

/// How many stars of one kind the sky has per million square pixels, and how
/// they look: the layers go from the faint dust to the bright stars with a
/// halo and the few gold ones.
class _StarKind {
  const _StarKind({
    required this.perMegapixel,
    required this.size,
    required this.color,
    this.halo = 0,
    this.haloColor,
  });

  final double perMegapixel;
  final double size;
  final Color Function(ShelfTokens) color;
  final double halo;
  final Color Function(ShelfTokens)? haloColor;
}

final _starKinds = [
  _StarKind(perMegapixel: 300, size: 1, color: (t) => t.starC),
  _StarKind(perMegapixel: 140, size: 1.5, color: (t) => t.starB),
  _StarKind(perMegapixel: 220, size: 1, color: (t) => t.starA),
  _StarKind(
    perMegapixel: 26,
    size: 1.5,
    color: (t) => t.starHot,
    halo: 7,
    haloColor: (t) => t.starHalo,
  ),
  _StarKind(
    perMegapixel: 14,
    size: 2,
    color: (t) => t.starHot,
    halo: 8,
    haloColor: (t) => t.starHalo,
  ),
  _StarKind(
    perMegapixel: 7,
    size: 2,
    color: (t) => t.starGold,
    halo: 9,
    haloColor: (t) => t.starGoldHalo,
  ),
];

const _dotShare = 0.6;

/// The sky is laid out once on a canvas of 4096 x 2304 px with a fixed seed;
/// a window shows the part of it that fits, so the stars do not move when it
/// is resized.
const _skySize = Size(4096, 2304);

List<AtmosphereStar>? _skyCache;
ShelfTokens? _skyTokens;

/// Every star that falls inside a window of [size], lowest kind first, at
/// random positions that are the same every time.
List<AtmosphereStar> atmosphereStars(Size size, ShelfTokens tokens) {
  if (_skyCache == null || _skyTokens != tokens) {
    final random = math.Random(2718);
    final megapixels = _skySize.width * _skySize.height / 1e6;
    final all = <AtmosphereStar>[];
    for (final kind in _starKinds) {
      final count = (kind.perMegapixel * megapixels).round();
      for (var i = 0; i < count; i++) {
        all.add(
          AtmosphereStar(
            center: Offset(
              random.nextDouble() * _skySize.width,
              random.nextDouble() * _skySize.height,
            ),
            radius: kind.size * _dotShare,
            color: kind.color(tokens),
            halo: kind.halo,
            haloColor: kind.haloColor?.call(tokens) ?? const Color(0x00000000),
          ),
        );
      }
    }
    _skyCache = all;
    _skyTokens = tokens;
  }
  return [
    for (final star in _skyCache!)
      if (star.center.dx < size.width + 12 && star.center.dy < size.height + 12)
        star,
  ];
}

/// Paints the still part of the space look behind the window content: the
/// sky gradient over the top 42%, the orbit rings and, when [moving] is off,
/// the star layers and four nebulae too (the moving sky draws those itself).
class AtmospherePainter extends CustomPainter {
  const AtmospherePainter(this.tokens, {this.moving = false});

  final ShelfTokens tokens;

  /// Whether [AtmosphereMotionPainter] draws the stars and nebulae.
  final bool moving;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = tokens.background);
    if (!moving) {
      for (final star in atmosphereStars(size, tokens)) {
        if (star.halo > 0) {
          _halo(canvas, star.center, star.halo, star.haloColor);
        }
        canvas.drawCircle(
          star.center,
          star.radius,
          Paint()..color = star.color,
        );
      }
    }
    _rings(canvas, size, tokens);
    if (!moving) {
      for (final nebula in _nebulae) {
        _paintNebula(
          canvas,
          size,
          nebula.color(tokens),
          nebula,
          1,
          Offset.zero,
        );
      }
    }
    _sky(canvas, size);
  }

  void _sky(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.42);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [tokens.sky, tokens.sky.withValues(alpha: 0)],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(AtmospherePainter oldDelegate) {
    return oldDelegate.tokens != tokens || oldDelegate.moving != moving;
  }
}

void _halo(Canvas canvas, Offset center, double radius, Color color) {
  final shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
      .createShader(Rect.fromCircle(center: center, radius: radius));
  canvas.drawCircle(center, radius, Paint()..shader = shader);
}

/// The centres of the three orbit rings.
List<(Offset, double)> _ringShapes(Size size) => [
  (Offset(size.width * -0.04, size.height * -0.08), 300),
  (Offset(size.width * 1.04, size.height * 1.08), 420),
  (Offset(size.width * 1.04, size.height * 1.08), 640),
];

void _rings(Canvas canvas, Size size, ShelfTokens tokens) {
  final paint = Paint()
    ..color = tokens.orbit
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  for (final (center, radius) in _ringShapes(size)) {
    canvas.drawCircle(center, radius, paint);
  }
}

class _Nebula {
  const _Nebula(this.color, this.radiusX, this.radiusY, this.x, this.y);

  final Color Function(ShelfTokens) color;
  final double radiusX;
  final double radiusY;
  final double x;
  final double y;
}

final _nebulae = [
  _Nebula((t) => t.nebula4, 700, 360, 0.40, 0.06),
  _Nebula((t) => t.nebula2, 820, 460, 0.62, 1.18),
  _Nebula((t) => t.nebula3, 760, 520, -0.08, 0.48),
  _Nebula((t) => t.nebula1, 900, 640, 0.96, -0.12),
];

/// Draws one nebula; [strength] scales its colour, [shift] moves it.
void _paintNebula(
  Canvas canvas,
  Size size,
  Color color,
  _Nebula nebula,
  double strength,
  Offset shift,
) {
  final tinted = color.withValues(alpha: color.a * strength.clamp(0, 1.4));
  final shader = RadialGradient(
    colors: [tinted, tinted.withValues(alpha: 0)],
    stops: const [0, 0.7],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: nebula.radiusX));
  canvas
    ..save()
    ..translate(
      size.width * nebula.x + shift.dx,
      size.height * nebula.y + shift.dy,
    )
    ..scale(1, nebula.radiusY / nebula.radiusX)
    ..drawCircle(Offset.zero, nebula.radiusX, Paint()..shader = shader)
    ..restore();
}

/// Whether the sky of the window moves: the bright stars twinkle, the dust
/// drifts in three depths, nebulae breathe, shooting stars cross the sky and
/// a moon travels each orbit ring. Off when the system asks for less motion
/// or the user turned it off; tests switch it off so that they can settle and
/// compare images.
bool atmosphereMotion = true;

/// How long a shooting star is under way, in seconds.
const _shootingSeconds = 1.2;

/// Seconds between the shooting stars of the cycle on average.
const _shootingCycle = 90.0;

class _ShootingEvent {
  const _ShootingEvent({
    required this.start,
    required this.origin,
    required this.angle,
    required this.travel,
    required this.length,
  });

  final double start;
  final Offset origin;
  final double angle;
  final double travel;
  final double length;
}

/// A shooting star every four seconds or so, from a fixed seed so that a cycle
/// always looks the same; some are long and bright.
final _shootingEvents = () {
  final random = math.Random(31415);
  const count = 22;
  return [
    for (var i = 0; i < count; i++)
      _ShootingEvent(
        start: (i + 0.15 + random.nextDouble() * 0.7) / count * _shootingCycle,
        origin: Offset(
          0.08 + random.nextDouble() * 0.84,
          0.04 + random.nextDouble() * 0.8,
        ),
        angle:
            (random.nextBool() ? 1 : -1) * (0.35 + random.nextDouble() * 0.6) +
            (random.nextBool() ? 0 : math.pi),
        travel: 420 + random.nextDouble() * 520,
        length: 90 + random.nextDouble() * 150,
      ),
  ];
}();

/// How long the twinkle and the orbit moons take for one turn.
const atmosphereCycle = Duration(seconds: 120);

/// How long the clock of the moving sky runs before it starts again.
const atmosphereClock = Duration(hours: 1);

/// The drifting dust: the dots of one colour and size as points, so that a
/// layer is one draw call.
class _DustLayer {
  const _DustLayer(this.points, this.color, this.size, this.speed);

  final Float32List points;
  final Color color;
  final double size;
  final double speed;
}

/// The moving part of the sky. [progress] is the clock from 0 to 1 over
/// [atmosphereClock].
class AtmosphereMotionPainter extends CustomPainter {
  AtmosphereMotionPainter(this.tokens, this.progress)
    : super(repaint: progress);

  final ShelfTokens tokens;
  final ValueListenable<double> progress;

  Size? _dustSize;
  List<_DustLayer> _dust = const [];
  List<AtmosphereStar> _bright = const [];

  void _prepare(Size size) {
    if (_dustSize == size) return;
    _dustSize = size;
    final groups = <(Color, double), List<double>>{};
    final bright = <AtmosphereStar>[];
    for (final star in atmosphereStars(size, tokens)) {
      if (star.halo > 0) {
        bright.add(star);
        continue;
      }
      (groups[(star.color, star.radius)] ??= []).addAll([
        star.center.dx,
        star.center.dy,
      ]);
    }
    _bright = bright;
    var depth = 0;
    _dust = [
      for (final entry in groups.entries)
        _DustLayer(
          Float32List.fromList(entry.value),
          entry.key.$1,
          entry.key.$2 * 2,
          const [4.0, 9.0, 15.0][depth++ % 3],
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    _prepare(size);
    final seconds = progress.value * atmosphereClock.inSeconds;
    final turn = seconds / atmosphereCycle.inSeconds * 2 * math.pi;
    _nebulaeBreathing(canvas, size, seconds);
    _dustDrift(canvas, size, seconds);
    _twinkle(canvas, turn);
    _shootingStars(canvas, size, seconds % _shootingCycle);
    _pulse(canvas, size, seconds);
    _moons(canvas, size, turn);
  }

  void _nebulaeBreathing(Canvas canvas, Size size, double seconds) {
    for (final (index, nebula) in _nebulae.indexed) {
      final phase = seconds / (11 + index * 3) + index * 1.7;
      _paintNebula(
        canvas,
        size,
        nebula.color(tokens),
        nebula,
        0.8 + 0.3 * math.sin(phase),
        Offset(26 * math.sin(phase * 0.7), 18 * math.cos(phase * 0.6)),
      );
    }
  }

  void _dustDrift(Canvas canvas, Size size, double seconds) {
    for (final layer in _dust) {
      final dx = (seconds * layer.speed) % size.width;
      final dy = (seconds * layer.speed * 0.3) % size.height;
      final paint = Paint()
        ..color = layer.color
        ..strokeWidth = layer.size
        ..strokeCap = StrokeCap.round;
      for (final shiftX in [dx, dx - size.width]) {
        for (final shiftY in [dy, dy - size.height]) {
          canvas
            ..save()
            ..translate(shiftX, shiftY)
            ..drawRawPoints(ui.PointMode.points, layer.points, paint)
            ..restore();
        }
      }
    }
  }

  void _twinkle(Canvas canvas, double turn) {
    var index = 0;
    for (final star in _bright) {
      index++;
      final wave = math.sin(turn * (24 + index % 5) + index * 1.9);
      final strength = 0.62 + 0.38 * wave;
      _halo(
        canvas,
        star.center,
        star.halo * (0.9 + 0.25 * strength),
        star.haloColor.withValues(alpha: star.haloColor.a * strength),
      );
      canvas.drawCircle(
        star.center,
        star.radius * (0.85 + 0.3 * strength),
        Paint()..color = star.color.withValues(alpha: 0.55 + 0.45 * strength),
      );
    }
  }

  void _shootingStars(Canvas canvas, Size size, double second) {
    for (final event in _shootingEvents) {
      final t = (second - event.start) / _shootingSeconds;
      if (t < 0 || t > 1) continue;
      final fade = math.sin(t * math.pi);
      final direction = Offset(math.cos(event.angle), math.sin(event.angle));
      final origin = Offset(
        event.origin.dx * size.width,
        event.origin.dy * size.height * 0.8,
      );
      final head = origin + direction * (event.travel * t);
      final tail = head - direction * event.length;
      final paint = Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            tokens.starHot.withValues(alpha: 0),
            tokens.starHot.withValues(alpha: 0.95 * fade),
          ],
        ).createShader(Rect.fromPoints(tail, head));
      canvas
        ..drawLine(tail, head, paint)
        ..drawCircle(
          head,
          6,
          Paint()..color = tokens.starHalo.withValues(alpha: 0.5 * fade),
        )
        ..drawCircle(
          head,
          2.2,
          Paint()..color = tokens.starHot.withValues(alpha: fade),
        );
    }
  }

  /// A faint ring that widens from the lower right corner every half minute.
  void _pulse(Canvas canvas, Size size, double seconds) {
    const period = 30.0;
    final t = (seconds % period) / 9;
    if (t > 1) return;
    final radius = 120 + 1100 * Curves.easeOut.transform(t);
    canvas.drawCircle(
      Offset(size.width * 1.04, size.height * 1.08),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = tokens.glow.withValues(alpha: 0.22 * (1 - t)),
    );
  }

  void _moons(Canvas canvas, Size size, double turn) {
    const starts = [0.0, 2.1, 4.0];
    const directions = [1.0, -1.0, 1.0];
    for (final (index, (center, radius)) in _ringShapes(size).indexed) {
      final angle = starts[index] + directions[index] * turn * 2;
      final moon = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (!(Offset.zero & size).inflate(8).contains(moon)) continue;
      _halo(canvas, moon, 9, tokens.accent.withValues(alpha: 0.45));
      canvas.drawCircle(moon, 2.2, Paint()..color = tokens.accentA);
    }
  }

  @override
  bool shouldRepaint(AtmosphereMotionPainter oldDelegate) {
    return oldDelegate.tokens != tokens || oldDelegate.progress != progress;
  }
}

/// The clock of the moving sky at 30 frames per second at most: the ticker
/// runs at the rate of the display, the dust and the stars do not need it.
class _SkyClock extends ChangeNotifier implements ValueListenable<double> {
  _SkyClock(this._source) {
    _value = _source.value;
    _source.addListener(_onTick);
  }

  static const _step = 1 / 30 / 3600;

  final Animation<double> _source;
  late double _value;

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

class _MovingSky extends StatefulWidget {
  const _MovingSky({required this.tokens});

  final ShelfTokens tokens;

  @override
  State<_MovingSky> createState() => _MovingSkyState();
}

class _MovingSkyState extends State<_MovingSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: atmosphereClock,
  )..repeat();
  late final _SkyClock _clock = _SkyClock(_controller);

  @override
  void dispose() {
    _clock.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: AtmosphereMotionPainter(widget.tokens, _clock),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// The window background: the atmosphere of the current theme behind [child].
class AtmosphereBackground extends ConsumerWidget {
  const AtmosphereBackground({required this.child, this.orbs, super.key});

  final Widget child;

  /// Whether the drifting orbs of the Freaky theme show; by default they do
  /// for that theme unless the system asks for less motion.
  final bool? orbs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final reduced = MediaQuery.of(context).disableAnimations;
    final showOrbs =
        orbs ?? (ref.watch(resolvedThemeProvider).id == 'freaky' && !reduced);
    final moving =
        atmosphereMotion && !reduced && ref.watch(backgroundMotionProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: AtmospherePainter(tokens, moving: moving),
            size: Size.infinite,
          ),
        ),
        if (moving) _MovingSky(tokens: tokens),
        if (showOrbs) const FreakyOrbs(),
        child,
      ],
    );
  }
}
