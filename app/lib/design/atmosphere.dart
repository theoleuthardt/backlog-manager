import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

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
  const AtmospherePainter(this.tokens);

  final ShelfTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = tokens.background);
    for (final star in atmosphereStars(size, tokens)) {
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
    return oldDelegate.tokens != tokens;
  }
}

/// The window background: the atmosphere of the current theme behind [child].
class AtmosphereBackground extends StatelessWidget {
  const AtmosphereBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: AtmospherePainter(tokens),
            size: Size.infinite,
          ),
        ),
        child,
      ],
    );
  }
}
