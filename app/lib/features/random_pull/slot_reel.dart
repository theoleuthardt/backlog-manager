import 'dart:math';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/random_pull.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long the reel spins before it stops on the pulled game.
const slotReelDuration = Duration(milliseconds: 5000);

const _rowHeight = 64.0;

/// A slot machine reel: [strip] runs through a window of three rows, quickly
/// at first and slower and slower, and stops with its [ReelStrip.stopIndex]
/// game on the highlighted middle row, with more games below it. [onDone] is
/// called once it has stopped, at once when the system asks for less motion.
/// A new spin needs a new key: the state starts the animation once.
class SlotReel extends ConsumerStatefulWidget {
  const SlotReel({required this.strip, required this.onDone, super.key});

  final ReelStrip strip;
  final VoidCallback onDone;

  @override
  ConsumerState<SlotReel> createState() => _SlotReelState();
}

class _SlotReelState extends ConsumerState<SlotReel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: slotReelDuration,
  );
  late final CurvedAnimation _position = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  final _scroll = ScrollController();
  bool _started = false;

  /// How many rows the reel runs through: the pulled game ends on the middle
  /// row of three, so the first game is already in the window.
  int get _distance => max(0, widget.strip.stopIndex - 1);

  @override
  void initState() {
    super.initState();
    _position.addListener(() {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_position.value * _distance * _rowHeight);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone();
      });
      _controller.value = 1;
      return;
    }
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _position.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final server = ref.watch(serverUrlProvider).value;

    return Semantics(
      label: 'Pulling a random game',
      child: ExcludeSemantics(
        child: SizedBox(
          key: const Key('random-pull-reel'),
          height: _rowHeight * 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.borderStrong),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scroll,
                    physics: const NeverScrollableScrollPhysics(),
                    itemExtent: _rowHeight,
                    itemCount: widget.strip.games.length,
                    itemBuilder: (context, index) => _ReelRow(
                      entry: widget.strip.games[index],
                      server: server,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              tokens.surface2,
                              tokens.surface2.withValues(alpha: 0),
                              tokens.surface2.withValues(alpha: 0),
                              tokens.surface2,
                            ],
                            stops: const [0, 0.3, 0.7, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _rowHeight,
                    height: _rowHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: tokens.accent,
                              width: 2,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(color: tokens.glowSoft, blurRadius: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const Key('random-pull-pointer'),
                        painter: _PointerPainter(
                          progress: _controller,
                          rows: _distance,
                          sparkColor: tokens.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The metal arrow at the right edge of the reel, pointing at the middle
/// row, and the sparks it throws while the reel runs past it.
class _PointerPainter extends CustomPainter {
  _PointerPainter({
    required this.progress,
    required this.rows,
    required this.sparkColor,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final int rows;
  final Color sparkColor;

  static const _width = 30.0;
  static const _height = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = Offset(size.width - _width - 4, size.height / 2);
    _sparks(canvas, tip);
    _arrow(canvas, size, tip);
  }

  void _sparks(Canvas canvas, Offset tip) {
    final power = reelSparks(
      progress.value,
      rows: rows,
      seconds: slotReelDuration.inMilliseconds / 1000,
    );
    if (power == 0) return;
    final passed = Curves.easeOutCubic.transform(progress.value) * rows;
    final age = passed - passed.floorToDouble();
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    for (var burst = 0; burst < 2; burst++) {
      final row = passed.floor() - burst;
      final burstAge = age + burst;
      if (burstAge > 1.6) continue;
      for (var spark = 0; spark < 14; spark++) {
        final random = Random(row * 31 + spark);
        final angle = pi + (random.nextDouble() - 0.5) * 2.2;
        final distance = (6 + burstAge * 26) * (0.5 + random.nextDouble());
        final fade = (1 - burstAge / 1.6) * power;
        final from = tip + Offset(cos(angle), sin(angle)) * distance;
        final to = tip + Offset(cos(angle), sin(angle)) * (distance + 10);
        paint.color = Color.lerp(
          const Color(0xFFFFFFFF),
          sparkColor,
          random.nextDouble(),
        )!.withValues(alpha: fade.clamp(0, 1));
        canvas.drawLine(from, to, paint);
      }
    }
  }

  void _arrow(Canvas canvas, Size size, Offset tip) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + _width, tip.dy - _height / 2)
      ..lineTo(tip.dx + _width, tip.dy + _height / 2)
      ..close();
    canvas
      ..drawShadow(path, const Color(0xFF000000), 4, true)
      ..drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF4F7FA),
              Color(0xFF9CA6B1),
              Color(0xFFE9EDF1),
              Color(0xFF626B75),
            ],
            stops: [0, 0.38, 0.6, 1],
          ).createShader(path.getBounds()),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF3A4048),
      )
      ..drawLine(
        Offset(tip.dx + 5, tip.dy - 2),
        Offset(tip.dx + _width - 3, tip.dy - _height / 2 + 4),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xCCFFFFFF),
      );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) =>
      oldDelegate.rows != rows || oldDelegate.sparkColor != sparkColor;
}

class _ReelRow extends StatelessWidget {
  const _ReelRow({required this.entry, required this.server});

  final BacklogEntry entry;
  final String? server;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final image = entryImage(server, entry.imageLink);
    return SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 44, 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: 34,
                height: _rowHeight - 12,
                child: image == null
                    ? ColoredBox(color: tokens.surface)
                    : Image(image: image, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.section.copyWith(color: tokens.foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
