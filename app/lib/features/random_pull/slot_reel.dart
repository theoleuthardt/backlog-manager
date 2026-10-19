import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long the reel spins before it stops on the pulled game.
const slotReelDuration = Duration(milliseconds: 2600);

const _rowHeight = 64.0;

/// A slot machine reel: [strip] runs through a window of three rows, quickly
/// at first and slower and slower, and stops with its last game on the
/// highlighted middle row. [onDone] is called once it has stopped, at once
/// when the system asks for less motion.
class SlotReel extends ConsumerStatefulWidget {
  const SlotReel({required this.strip, required this.onDone, super.key});

  final List<BacklogEntry> strip;
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
  late final Animation<double> _position = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final server = ref.watch(serverUrlProvider).value;
    final last = widget.strip.length - 1;

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
                  AnimatedBuilder(
                    animation: _position,
                    builder: (context, _) => OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          _rowHeight - _position.value * last * _rowHeight,
                        ),
                        child: Column(
                          children: [
                            for (final entry in widget.strip)
                              _ReelRow(entry: entry, server: server),
                          ],
                        ),
                      ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
