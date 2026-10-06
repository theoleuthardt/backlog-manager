import 'dart:math' as math;

import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// The mark of the app: a planet with a ring and a small moon, 26 px.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 26, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return CustomPaint(
      size: Size.square(size),
      painter: _PlanetPainter(tokens),
    );
  }
}

class _PlanetPainter extends CustomPainter {
  const _PlanetPainter(this.tokens);

  final ShelfTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 32;
    canvas
      ..save()
      ..scale(scale)
      ..save()
      ..translate(16, 16)
      ..rotate(-24 * math.pi / 180)
      ..drawOval(
        Rect.fromCenter(center: Offset.zero, width: 28, height: 11),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = tokens.glow,
      )
      ..restore()
      ..drawCircle(const Offset(16, 16), 6.5, Paint()..color = tokens.accent)
      ..drawCircle(const Offset(27, 9.5), 1.8, Paint()..color = tokens.accentA)
      ..restore();
  }

  @override
  bool shouldRepaint(_PlanetPainter oldDelegate) =>
      oldDelegate.tokens != tokens;
}
