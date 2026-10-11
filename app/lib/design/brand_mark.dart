import 'dart:math' as math;

import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The mark of the app: a planet with a ring and a small moon. The moon
/// travels along the ring and the planet breathes slowly; it stands still
/// when the system asks for less motion.
class BrandMark extends ConsumerStatefulWidget {
  const BrandMark({this.size = 26, super.key});

  final double size;

  @override
  ConsumerState<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends ConsumerState<BrandMark>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final moving =
        atmosphereMotion &&
        !MediaQuery.of(context).disableAnimations &&
        ref.watch(backgroundMotionProvider);
    if (moving && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 9),
      )..repeat();
    } else if (!moving && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _PlanetPainter(tokens, _controller),
    );
  }
}

class _PlanetPainter extends CustomPainter {
  _PlanetPainter(this.tokens, this.phase) : super(repaint: phase);

  final ShelfTokens tokens;
  final Animation<double>? phase;

  @override
  void paint(Canvas canvas, Size size) {
    final turn = (phase?.value ?? 0.07) * 2 * math.pi;
    final scale = size.width / 32;
    final breathe = 1 + 0.05 * math.sin(turn * 2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = tokens.glow;
    final back = Path()
      ..addArc(
        Rect.fromCenter(center: Offset.zero, width: 28, height: 11),
        math.pi,
        math.pi,
      );
    final front = Path()
      ..addArc(
        Rect.fromCenter(center: Offset.zero, width: 28, height: 11),
        0,
        math.pi,
      );
    final moon = Offset(14 * math.cos(turn), 5.5 * math.sin(turn));
    final moonInFront = math.sin(turn) > 0;

    void moonDot(Canvas canvas) {
      canvas
        ..drawCircle(
          moon,
          3.2,
          Paint()..color = tokens.accentA.withValues(alpha: 0.28),
        )
        ..drawCircle(moon, 1.8, Paint()..color = tokens.accentA);
    }

    canvas
      ..save()
      ..scale(scale)
      ..save()
      ..translate(16, 16)
      ..rotate(-24 * math.pi / 180)
      ..drawPath(back, ringPaint);
    if (!moonInFront) moonDot(canvas);
    canvas
      ..restore()
      ..drawCircle(
        const Offset(16, 16),
        6.5 * breathe,
        Paint()..color = tokens.accent,
      )
      ..save()
      ..translate(16, 16)
      ..rotate(-24 * math.pi / 180)
      ..drawPath(front, ringPaint);
    if (moonInFront) moonDot(canvas);
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_PlanetPainter oldDelegate) =>
      oldDelegate.tokens != tokens || oldDelegate.phase != phase;
}
