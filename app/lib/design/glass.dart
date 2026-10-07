import 'dart:ui';

import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// Switches for the costly parts of the atmosphere; put it above the window
/// content. The blur can be turned off for slow systems, the glass is then
/// only a translucent tint.
class AtmosphereSettings extends InheritedWidget {
  const AtmosphereSettings({
    required this.blurEnabled,
    required super.child,
    super.key,
  });

  final bool blurEnabled;

  /// Whether glass surfaces below [context] blur what is behind them.
  static bool blurEnabledOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AtmosphereSettings>()
            ?.blurEnabled ??
        true;
  }

  @override
  bool updateShouldNotify(AtmosphereSettings oldWidget) {
    return oldWidget.blurEnabled != blurEnabled;
  }
}

/// A translucent surface in the background colour with an optional blur of
/// what is behind it: title bar, sidebar, inspector and status bar.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.opacity,
    required this.blur,
    required this.child,
    super.key,
  });

  final double opacity;
  final double blur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final tinted = ColoredBox(
      color: atOpacity(tokens.background, opacity),
      child: child,
    );
    if (!AtmosphereSettings.blurEnabledOf(context)) return tinted;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: tinted,
      ),
    );
  }
}
