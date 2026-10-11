import 'dart:math' as math;

import 'package:backlog_manager/design/freaky_orbs.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
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

class _StarLayer {
  const _StarLayer({
    required this.tile,
    required this.offset,
    required this.size,
    required this.color,
    this.halo = 0,
    this.haloColor,
  });

  final Size tile;
  final Offset offset;
  final double size;
  final Color Function(ShelfTokens) color;
  final double halo;
  final Color Function(ShelfTokens)? haloColor;
}

/// The star layers from the lowest to the highest, with the tile each one
/// repeats and the position of its star inside the tile (the staggered tile
/// sizes keep the pattern from visibly repeating).
final _starLayers = [
  _StarLayer(
    tile: const Size(340, 310),
    offset: const Offset(150, 60),
    size: 1,
    color: (t) => t.starC,
  ),
  _StarLayer(
    tile: const Size(270, 230),
    offset: const Offset(40, 118),
    size: 1.5,
    color: (t) => t.starB,
  ),
  _StarLayer(
    tile: const Size(190, 170),
    offset: const Offset(96, 30),
    size: 1,
    color: (t) => t.starC,
  ),
  _StarLayer(
    tile: const Size(150, 130),
    offset: const Offset(70, 84),
    size: 1,
    color: (t) => t.starB,
  ),
  _StarLayer(
    tile: const Size(120, 110),
    offset: const Offset(12, 22),
    size: 1,
    color: (t) => t.starA,
  ),
  _StarLayer(
    tile: const Size(430, 380),
    offset: const Offset(210, 150),
    size: 1.5,
    color: (t) => t.starHot,
    halo: 7,
    haloColor: (t) => t.starHalo,
  ),
  _StarLayer(
    tile: const Size(310, 260),
    offset: const Offset(58, 44),
    size: 2,
    color: (t) => t.starHot,
    halo: 8,
    haloColor: (t) => t.starHalo,
  ),
  _StarLayer(
    tile: const Size(520, 420),
    offset: const Offset(130, 200),
    size: 2,
    color: (t) => t.starGold,
    halo: 9,
    haloColor: (t) => t.starGoldHalo,
  ),
];

const _dotShare = 0.6;

/// Every star that falls inside a window of [size], lowest layer first. The
/// positions are fixed by the tiles, so the sky does not flicker or move when
/// the window is resized.
List<AtmosphereStar> atmosphereStars(Size size, ShelfTokens tokens) {
  final stars = <AtmosphereStar>[];
  for (final layer in _starLayers) {
    for (var y = layer.offset.dy; y < size.height; y += layer.tile.height) {
      for (var x = layer.offset.dx; x < size.width; x += layer.tile.width) {
        stars.add(
          AtmosphereStar(
            center: Offset(x, y),
            radius: layer.size * _dotShare,
            color: layer.color(tokens),
            halo: layer.halo,
            haloColor: layer.haloColor?.call(tokens) ?? const Color(0x00000000),
          ),
        );
      }
    }
  }
  return stars;
}

/// Paints the space look behind the window content: the sky gradient over the
/// top 42%, four nebulae, three orbit rings around the corners and the star
/// layers, all in the colours of the tokens.
class AtmospherePainter extends CustomPainter {
  const AtmospherePainter(this.tokens, {this.brightStars = true});

  final ShelfTokens tokens;

  /// Whether the stars with a halo are part of this layer. The animated sky
  /// draws them itself ([AtmosphereTwinklePainter]) so they can twinkle.
  final bool brightStars;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = tokens.background);
    for (final star in atmosphereStars(size, tokens)) {
      if (star.halo > 0 && !brightStars) continue;
      if (star.halo > 0) _halo(canvas, star);
      canvas.drawCircle(star.center, star.radius, Paint()..color = star.color);
    }
    _rings(canvas, size);
    _nebula(canvas, size, tokens.nebula4, 700, 360, 0.40, 0.06);
    _nebula(canvas, size, tokens.nebula2, 820, 460, 0.62, 1.18);
    _nebula(canvas, size, tokens.nebula3, 760, 520, -0.08, 0.48);
    _nebula(canvas, size, tokens.nebula1, 900, 640, 0.96, -0.12);
    _sky(canvas, size);
  }

  void _halo(Canvas canvas, AtmosphereStar star) {
    final shader = RadialGradient(
      colors: [star.haloColor, star.haloColor.withValues(alpha: 0)],
    ).createShader(Rect.fromCircle(center: star.center, radius: star.halo));
    canvas.drawCircle(star.center, star.halo, Paint()..shader = shader);
  }

  void _rings(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = tokens.orbit
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final top = Offset(size.width * -0.04, size.height * -0.08);
    final bottom = Offset(size.width * 1.04, size.height * 1.08);
    canvas.drawCircle(top, 300, paint);
    canvas.drawCircle(bottom, 420, paint);
    canvas.drawCircle(bottom, 640, paint);
  }

  void _nebula(
    Canvas canvas,
    Size size,
    Color color,
    double radiusX,
    double radiusY,
    double centerX,
    double centerY,
  ) {
    final shader = RadialGradient(
      colors: [color, color.withValues(alpha: 0)],
      stops: const [0, 0.7],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: radiusX));
    canvas
      ..save()
      ..translate(size.width * centerX, size.height * centerY)
      ..scale(1, radiusY / radiusX)
      ..drawCircle(Offset.zero, radiusX, Paint()..shader = shader)
      ..restore();
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
    return oldDelegate.tokens != tokens ||
        oldDelegate.brightStars != brightStars;
  }
}

/// Whether the sky of the window moves: the bright stars twinkle and a small
/// moon travels each orbit ring. Off when the system asks for less motion;
/// tests switch it off so that they can settle and compare images.
bool atmosphereMotion = true;

/// How long the twinkle and the orbits take for one turn.
const atmosphereCycle = Duration(seconds: 120);

/// The moving part of the sky: the stars with a halo, twinkling, and one moon
/// on each orbit ring. [progress] runs from 0 to 1 once per [atmosphereCycle].
class AtmosphereTwinklePainter extends CustomPainter {
  const AtmosphereTwinklePainter(this.tokens, this.progress)
    : super(repaint: progress);

  final ShelfTokens tokens;
  final Animation<double> progress;

  static Size? _cachedSize;
  static ShelfTokens? _cachedTokens;
  static List<AtmosphereStar> _bright = const [];

  List<AtmosphereStar> _brightStars(Size size) {
    if (_cachedSize != size || _cachedTokens != tokens) {
      _cachedSize = size;
      _cachedTokens = tokens;
      _bright = [
        for (final star in atmosphereStars(size, tokens))
          if (star.halo > 0) star,
      ];
    }
    return _bright;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final turn = progress.value * 2 * math.pi;
    var index = 0;
    for (final star in _brightStars(size)) {
      index++;
      final wave = math.sin(turn * (24 + index % 5) + index * 1.9);
      final strength = 0.62 + 0.38 * wave;
      final halo = Paint()
        ..shader = RadialGradient(
          colors: [
            star.haloColor.withValues(
              alpha: star.haloColor.a * strength.clamp(0, 1),
            ),
            star.haloColor.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: star.center, radius: star.halo));
      canvas
        ..drawCircle(star.center, star.halo, halo)
        ..drawCircle(
          star.center,
          star.radius * (0.85 + 0.3 * strength),
          Paint()..color = star.color.withValues(alpha: 0.55 + 0.45 * strength),
        );
    }
    final rings = [
      (Offset(size.width * -0.04, size.height * -0.08), 300.0, 0.0, 1.0),
      (Offset(size.width * 1.04, size.height * 1.08), 420.0, 2.1, -1.0),
      (Offset(size.width * 1.04, size.height * 1.08), 640.0, 4.0, 1.0),
    ];
    for (final (center, radius, start, direction) in rings) {
      final angle = start + direction * turn * 2;
      final moon = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (!(Offset.zero & size).inflate(8).contains(moon)) continue;
      canvas
        ..drawCircle(
          moon,
          9,
          Paint()
            ..shader = RadialGradient(
              colors: [
                tokens.accent.withValues(alpha: 0.45),
                tokens.accent.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: moon, radius: 9)),
        )
        ..drawCircle(moon, 2.2, Paint()..color = tokens.accentA);
    }
  }

  @override
  bool shouldRepaint(AtmosphereTwinklePainter oldDelegate) {
    return oldDelegate.tokens != tokens || oldDelegate.progress != progress;
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
    duration: atmosphereCycle,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: AtmosphereTwinklePainter(widget.tokens, _controller),
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
    final showOrbs =
        orbs ??
        (ref.watch(resolvedThemeProvider).id == 'freaky' &&
            !MediaQuery.of(context).disableAnimations);
    final moving =
        atmosphereMotion && !MediaQuery.of(context).disableAnimations;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: AtmospherePainter(tokens, brightStars: !moving),
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
