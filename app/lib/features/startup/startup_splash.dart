import 'dart:async';
import 'dart:math' as math;

import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/spinner.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long the start animation runs at least.
const startupSplashDuration = Duration(milliseconds: 3000);

/// The fade into the app once the animation and the session check are done.
const startupSplashFade = Duration(milliseconds: 500);

/// The words of the wordmark.
const startupWordmark = 'Backlog Manager';

/// Shows the start animation above [child] when the app starts: the Saturn of
/// the brand mark arrives over the sky and the wordmark appears letter by
/// letter with a sweep of light. It ends when the animation has run and the
/// session check is over, fades into the sign-in page or the shell, and can be
/// skipped with a click or a key. It is not shown at all while the system asks
/// for less motion, while the background is not animated and in tests.
class StartupSplash extends ConsumerStatefulWidget {
  const StartupSplash({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends ConsumerState<StartupSplash>
    with TickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: startupSplashDuration,
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: startupSplashFade,
  );
  bool _started = false;
  bool _gone = false;

  @override
  void dispose() {
    _run.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _skip() {
    if (_run.isCompleted) return;
    _run.value = 1;
    _maybeLeave(ref.read(sessionProvider));
  }

  void _maybeLeave(SessionState session) {
    if (_gone || _fade.isAnimating || _fade.isCompleted) return;
    if (!_run.isCompleted || session is SessionLoading) return;
    unawaited(
      _fade.forward().whenComplete(() {
        if (mounted) setState(() => _gone = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moving =
        atmosphereMotion &&
        !MediaQuery.of(context).disableAnimations &&
        ref.watch(backgroundMotionProvider);
    final session = ref.watch(sessionProvider);
    if (!moving || _gone) return widget.child;

    if (!_started) {
      _started = true;
      unawaited(
        _run.forward().whenComplete(() {
          if (mounted) _maybeLeave(ref.read(sessionProvider));
        }),
      );
    }
    ref.listen(sessionProvider, (_, next) => _maybeLeave(next));
    _maybeLeave(session);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        FadeTransition(
          opacity: ReverseAnimation(_fade),
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) _skip();
              return KeyEventResult.handled;
            },
            child: GestureDetector(
              key: const Key('startup-splash'),
              behavior: HitTestBehavior.opaque,
              onTap: _skip,
              child: _SplashScene(progress: _run),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashScene extends StatelessWidget {
  const _SplashScene({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return ColoredBox(
      color: tokens.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: AtmospherePainter(tokens)),
          AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final t = progress.value;
              final arrival = Curves.easeOutBack.transform(
                (t / 0.32).clamp(0.0, 1.0),
              );
              final glow = Curves.easeOut.transform((t / 0.4).clamp(0.0, 1.0));
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: glow,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    tokens.accent.withValues(alpha: 0.28),
                                    tokens.accent.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Transform.scale(
                            scale: 0.4 + 0.6 * arrival,
                            child: Opacity(
                              opacity: arrival.clamp(0.0, 1.0),
                              child: Transform.rotate(
                                angle: (1 - arrival) * -0.9,
                                child: SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: CustomPaint(
                                    key: const Key('startup-saturn'),
                                    painter: SaturnSpinnerPainter(
                                      tokens: tokens,
                                      phase: progress,
                                      color: tokens.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _Wordmark(t: t, style: text.hero, tokens: tokens),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The wordmark: letter by letter from 0.28 of the run, then one sweep of
/// light over it.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.t, required this.style, required this.tokens});

  final double t;
  final TextStyle style;
  final ShelfTokens tokens;

  @override
  Widget build(BuildContext context) {
    final letters = startupWordmark.characters.toList();
    final big = style.copyWith(
      fontSize: 64,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
      color: tokens.foreground,
    );
    final sweep = ((t - 0.62) / 0.3).clamp(0.0, 1.0);

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          tokens.accent.withValues(alpha: 0.9),
          Colors.transparent,
        ],
        stops: [
          math.max(0, sweep * 1.4 - 0.4),
          sweep * 1.4 - 0.2,
          math.min(1, sweep * 1.4),
        ],
      ).createShader(bounds),
      child: Row(
        key: const Key('startup-wordmark'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < letters.length; i++)
            _Letter(
              letter: letters[i],
              style: big,
              reveal: Curves.easeOutCubic.transform(
                ((t - 0.28 - i * 0.032) / 0.16).clamp(0.0, 1.0),
              ),
            ),
        ],
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.letter,
    required this.style,
    required this.reveal,
  });

  final String letter;
  final TextStyle style;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: reveal,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - reveal)),
        child: Text(letter == ' ' ? ' ' : letter, style: style),
      ),
    );
  }
}
