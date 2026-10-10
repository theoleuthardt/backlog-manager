import 'dart:math';
import 'dart:ui' as ui;

import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/orbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Drifting, pulsing neon orbs for the Freaky theme, tinted with the accent
/// and the glow colour of the theme and added onto what is behind them. It
/// paints on every frame and takes no part in layout or in hit testing.
class FreakyOrbs extends StatefulWidget {
  const FreakyOrbs({this.random, super.key});

  /// The source of the starting positions; tests pass a seeded one.
  final Random? random;

  @override
  State<FreakyOrbs> createState() => _FreakyOrbsState();
}

class _FreakyOrbsState extends State<FreakyOrbs>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  List<Orb>? _orbs;
  Size2 _size = const Size2(0, 0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final orbs = _orbs;
      if (orbs != null) {
        for (final orb in orbs) {
          orb.step(_size);
        }
      }
      _frame.value++;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _size = Size2(constraints.maxWidth, constraints.maxHeight);
              _orbs ??= createOrbs(_size, widget.random ?? Random());
              return CustomPaint(
                key: const Key('freaky-orbs'),
                painter: _OrbPainter(
                  orbs: _orbs!,
                  frame: _frame,
                  accent: tokens.accent,
                  glow: tokens.glow,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.orbs,
    required this.frame,
    required this.accent,
    required this.glow,
  }) : super(repaint: frame);

  final List<Orb> orbs;
  final ValueNotifier<int> frame;
  final Color accent;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      final radius = orb.radius * orbPulse(frame.value, orb.phase);
      final color = orb.useGlow ? glow : accent;
      final center = Offset(orb.x, orb.y);
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(center, radius, [
          color.withValues(alpha: 0.14),
          color.withValues(alpha: 0),
        ]);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.accent != accent || old.glow != glow || old.orbs != orbs;
}
