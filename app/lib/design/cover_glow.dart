import 'dart:async';
import 'dart:typed_data';

import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

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

/// Puts a glow in the colour of a cover behind [child]: a soft light around
/// the cover itself ([coverSize], at the top left) and a wide wash behind the
/// rest of the header. Without a picture, or until its colour is known, the
/// glow is the theme's own.
class CoverGlow extends StatefulWidget {
  const CoverGlow({
    required this.coverSize,
    required this.child,
    this.image,
    super.key,
  });

  final ImageProvider? image;
  final Size coverSize;
  final Widget child;

  @override
  State<CoverGlow> createState() => _CoverGlowState();
}

class _CoverGlowState extends State<CoverGlow> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CoverGlow oldWidget) {
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
      builder: (context, color, child) {
        final glow = color ?? target;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -60,
              right: -60,
              top: -50,
              bottom: -30,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const Key('cover-glow-wash'),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.55, -0.25),
                      radius: 0.95,
                      colors: [
                        glow.withValues(alpha: 0.34),
                        glow.withValues(alpha: 0.12),
                        glow.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: widget.coverSize.width,
              height: widget.coverSize.height,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const Key('cover-glow-halo'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.55),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
