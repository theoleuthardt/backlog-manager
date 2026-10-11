import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/background_motion.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The colour a cover glows in, taken from its RGBA [pixels]: the average of
/// the pixels weighted by how saturated they are (grey and black borders do
/// not count), then pushed to a bright, saturated shade that shows on a dark
/// and on a light window. Null when the picture has no colour at all.
Color? glowColorFromPixels(Uint8List pixels) {
  var red = 0.0;
  var green = 0.0;
  var blue = 0.0;
  var total = 0.0;
  for (var i = 0; i + 3 < pixels.length; i += 4) {
    if (pixels[i + 3] < 128) continue;
    final r = pixels[i] / 255;
    final g = pixels[i + 1] / 255;
    final b = pixels[i + 2] / 255;
    final high = [r, g, b].reduce((a, c) => a > c ? a : c);
    final low = [r, g, b].reduce((a, c) => a < c ? a : c);
    final chroma = high - low;
    final weight = chroma * chroma * (0.3 + high);
    red += r * weight;
    green += g * weight;
    blue += b * weight;
    total += weight;
  }
  if (total < 0.0001) return null;
  final average = Color.from(
    alpha: 1,
    red: red / total,
    green: green / total,
    blue: blue / total,
  );
  final hsl = HSLColor.fromColor(average);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.55, 1))
      .withLightness(hsl.lightness.clamp(0.5, 0.62))
      .toColor();
}

final _glowColors = <ImageProvider, Color?>{};

Future<Color?> _resolveGlow(ImageProvider provider) {
  if (_glowColors.containsKey(provider)) {
    return Future.value(_glowColors[provider]);
  }
  final completer = Completer<Color?>();
  final stream = ResizeImage(
    provider,
    width: 24,
    height: 24,
    allowUpscaling: false,
  ).resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) async {
      stream.removeListener(listener);
      try {
        final data = await info.image.toByteData();
        final color = data == null
            ? null
            : glowColorFromPixels(data.buffer.asUint8List());
        _glowColors[provider] = color;
        if (!completer.isCompleted) completer.complete(color);
      } on Object {
        if (!completer.isCompleted) completer.complete(null);
      }
    },
    onError: (error, stackTrace) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete(null);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

/// Holds the colour the glow of one cover has, for [CoverGlowBackdrop] and
/// [CoverGlowHalo] below it. The colour is taken from [image] and fades in;
/// without a picture, or until it is known, it is the theme's own glow.
class CoverGlowScope extends StatefulWidget {
  const CoverGlowScope({required this.child, this.image, super.key});

  final ImageProvider? image;
  final Widget child;

  @override
  State<CoverGlowScope> createState() => _CoverGlowScopeState();
}

class _CoverGlowScopeState extends State<CoverGlowScope> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CoverGlowScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _load();
  }

  void _load() {
    final image = widget.image;
    if (image == null) {
      _color = null;
      return;
    }
    unawaited(
      _resolveGlow(image).then((color) {
        if (mounted && widget.image == image) setState(() => _color = color);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final target = _color ?? tokens.glow;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 500),
      builder: (context, color, child) =>
          _GlowColor(color: color ?? target, child: child!),
      child: widget.child,
    );
  }
}

class _GlowColor extends InheritedWidget {
  const _GlowColor({required this.color, required super.child});

  final Color color;

  static Color of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_GlowColor>();
    return scope?.color ?? Theme.of(context).extension<ShelfTokens>()!.glow;
  }

  @override
  bool updateShouldNotify(_GlowColor oldWidget) => color != oldWidget.color;
}

/// The glow behind the header of a game (the cover, the title, the chips): a
/// veil from the top left that fades out towards the bottom, and two soft
/// lights that drift slowly inside that area, the way light moves in a room.
/// The lights stand still when [glowMotionProvider] is off, when the system
/// asks for less motion, and in tests. It fills the box it is given.
class CoverGlowBackdrop extends ConsumerStatefulWidget {
  const CoverGlowBackdrop({super.key});

  @override
  ConsumerState<CoverGlowBackdrop> createState() => _CoverGlowBackdropState();
}

class _CoverGlowBackdropState extends ConsumerState<CoverGlowBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 34),
  );

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Alignment _wander(double t, {required double phase, required double speed}) {
    final x = math.sin(2 * math.pi * (t * speed + phase));
    final y = math.cos(2 * math.pi * (t * speed * 0.73 + phase * 1.7));
    return Alignment(0.55 * x - 0.1, 0.35 * y - 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final glow = _GlowColor.of(context);
    final moving =
        atmosphereMotion &&
        !MediaQuery.of(context).disableAnimations &&
        ref.watch(glowMotionProvider);
    if (moving && !_drift.isAnimating) {
      unawaited(_drift.repeat());
    } else if (!moving && _drift.isAnimating) {
      _drift.stop();
    }

    Widget light(Alignment center, double alpha, double radius, Key key) {
      return DecoratedBox(
        key: key,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [
              glow.withValues(alpha: alpha),
              glow.withValues(alpha: alpha * 0.4),
              glow.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
      );
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _drift,
        builder: (context, _) {
          final t = _drift.value;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.5, 1],
            ).createShader(bounds),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  key: const Key('cover-glow-veil'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-1, -1),
                      end: const Alignment(0.9, 1),
                      colors: [
                        glow.withValues(alpha: 0.5),
                        glow.withValues(alpha: 0.36),
                        glow.withValues(alpha: 0.12),
                        glow.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.45, 0.8, 1],
                    ),
                  ),
                ),
                light(
                  moving
                      ? _wander(t, phase: 0, speed: 1)
                      : const Alignment(-0.6, -0.2),
                  0.34,
                  0.9,
                  const Key('cover-glow-light-a'),
                ),
                light(
                  moving
                      ? _wander(t, phase: 0.45, speed: 1.3)
                      : const Alignment(0.55, -0.1),
                  0.26,
                  0.75,
                  const Key('cover-glow-light-b'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A soft light around the cover that holds it, in the colour of the glow.
class CoverGlowHalo extends StatelessWidget {
  const CoverGlowHalo({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glow = _GlowColor.of(context);
    return DecoratedBox(
      key: const Key('cover-glow-halo'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.75),
            blurRadius: 46,
            spreadRadius: 4,
          ),
        ],
      ),
      child: child,
    );
  }
}
