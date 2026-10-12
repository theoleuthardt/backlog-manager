import 'dart:async';
import 'dart:math' as math;

import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// The loading indicator of the app: the planet of the brand mark with its
/// ring tilting and opening, a light that circles the planet, a moon that
/// runs round the ring and a few stars that flash. It stands still (one
/// pleasant frame) when the system asks for less motion and in tests.
class ShelfSpinner extends StatefulWidget {
  const ShelfSpinner({this.size = 24, this.color, super.key});

  final double size;

  /// The colour of the planet; the accent of the theme by default.
  final Color? color;

  @override
  State<ShelfSpinner> createState() => _ShelfSpinnerState();
}

class _ShelfSpinnerState extends State<ShelfSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final moving =
        atmosphereMotion && !MediaQuery.of(context).disableAnimations;
    if (moving && !_controller.isAnimating) {
      unawaited(_controller.repeat());
    } else if (!moving && _controller.isAnimating) {
      _controller.stop();
    }
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: CustomPaint(
          key: const Key('shelf-spinner'),
          size: Size.square(widget.size),
          painter: SaturnSpinnerPainter(
            tokens: tokens,
            phase: _controller,
            color: widget.color ?? tokens.accent,
            still: !moving,
          ),
        ),
      ),
    );
  }
}

/// Paints one frame of the spinner on a 32 x 32 unit square scaled to the
/// size of the canvas.
class SaturnSpinnerPainter extends CustomPainter {
  SaturnSpinnerPainter({
    required this.tokens,
    required this.phase,
    required this.color,
    this.still = false,
  }) : super(repaint: phase);

  final ShelfTokens tokens;
  final Animation<double> phase;
  final Color color;

  /// Paints the resting frame instead of the one of [phase].
  final bool still;

  static const _restingPhase = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? _restingPhase : phase.value;
    final turn = t * 2 * math.pi;
    final ringTilt = (-24 + 16 * math.sin(turn)) * math.pi / 180;
    final ringHeight = 8 + 3.5 * math.cos(turn);
    final glowRadius = 12.5 + 1.5 * math.sin(turn * 2);
    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: 29,
      height: ringHeight,
    );
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.7
      ..color = tokens.glow;
    final moonAngle = turn * 2;
    final moon = Offset(
      14.5 * math.cos(moonAngle),
      ringHeight / 2 * math.sin(moonAngle),
    );
    final moonInFront = math.sin(moonAngle) > 0;

    void moonDot() {
      canvas
        ..drawCircle(
          moon,
          3.4,
          Paint()..color = tokens.accentA.withValues(alpha: 0.3),
        )
        ..drawCircle(moon, 1.9, Paint()..color = tokens.accentA);
    }

    canvas
      ..save()
      ..scale(size.width / 32)
      ..drawCircle(
        const Offset(16, 16),
        glowRadius,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  color.withValues(alpha: 0.32),
                  color.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(
                  center: const Offset(16, 16),
                  radius: glowRadius,
                ),
              ),
      )
      ..save()
      ..translate(16, 16)
      ..rotate(ringTilt)
      ..drawArc(ringRect, math.pi, math.pi, false, ringPaint);
    if (!moonInFront) moonDot();
    canvas.restore();

    final lightX = 16 + 2.6 * math.cos(turn);
    final lightY = 16 - 2.2 * math.sin(turn);
    final planet = Rect.fromCircle(center: const Offset(16, 16), radius: 6.6);
    canvas
      ..drawCircle(
        const Offset(16, 16),
        6.6,
        Paint()
          ..shader = RadialGradient(
            center: Alignment((lightX - 16) / 6.6, (lightY - 16) / 6.6),
            radius: 1.15,
            colors: [
              Color.lerp(color, Colors.white, 0.6)!,
              color,
              Color.lerp(color, Colors.black, 0.45)!,
            ],
            stops: const [0, 0.5, 1],
          ).createShader(planet),
      )
      ..save()
      ..translate(16, 16)
      ..rotate(ringTilt)
      ..drawArc(ringRect, 0, math.pi, false, ringPaint);
    if (moonInFront) moonDot();
    canvas.restore();

    final stars = [
      (const Offset(5, 6), 0.0),
      (const Offset(27, 9), 0.33),
      (const Offset(24, 27), 0.66),
    ];
    for (final (center, offset) in stars) {
      final flash = math.max(0.0, math.sin(turn + offset * 2 * math.pi));
      if (flash <= 0.05) continue;
      final arm = 1.2 + 2.4 * flash;
      final paint = Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = tokens.accentA.withValues(alpha: 0.35 + 0.65 * flash);
      canvas
        ..drawLine(center.translate(-arm, 0), center.translate(arm, 0), paint)
        ..drawLine(center.translate(0, -arm), center.translate(0, arm), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SaturnSpinnerPainter oldDelegate) =>
      oldDelegate.tokens != tokens ||
      oldDelegate.color != color ||
      oldDelegate.still != still ||
      oldDelegate.phase != phase;
}
