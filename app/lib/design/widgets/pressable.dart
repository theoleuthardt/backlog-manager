import 'dart:async';

import 'package:backlog_manager/design/focus_glide.dart';
import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// What a [ShelfPressable] tells its builder about the pointer and keyboard.
class ShelfInteraction {
  const ShelfInteraction({
    required this.enabled,
    required this.hovered,
    required this.focused,
    required this.pressed,
  });

  final bool enabled;
  final bool hovered;

  /// Keyboard focus; the pressable draws the focus ring itself.
  final bool focused;
  final bool pressed;
}

/// The behaviour every clickable part of the design shares: hover, press, a
/// 2 px accent focus ring offset by 2 px for keyboard focus, Enter and Space,
/// the pointer cursor and button semantics. [builder] draws the look.
class ShelfPressable extends StatefulWidget {
  const ShelfPressable({
    required this.builder,
    this.onPressed,
    this.borderRadius = 8,
    this.pressedScale = 1,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final Widget Function(BuildContext context, ShelfInteraction state) builder;
  final VoidCallback? onPressed;

  /// The radius of the focus ring is this plus its offset.
  final double borderRadius;

  /// The scale the look shrinks to while the pointer is down, so buttons
  /// answer a press; 1 keeps the size.
  final double pressedScale;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<ShelfPressable> createState() => _ShelfPressableState();
}

class _ShelfPressableState extends State<ShelfPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _set({bool? hovered, bool? focused, bool? pressed}) {
    setState(() {
      _hovered = hovered ?? _hovered;
      _focused = focused ?? _focused;
      _pressed = pressed ?? _pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final state = ShelfInteraction(
      enabled: _enabled,
      hovered: _hovered && _enabled,
      focused: _focused && _enabled,
      pressed: _pressed && _enabled,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (value) => _set(focused: value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => _set(hovered: true),
          onExit: (_) => _set(hovered: false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            onTapDown: _enabled ? (_) => _set(pressed: true) : null,
            onTapUp: (_) => _set(pressed: false),
            onTapCancel: () => _set(pressed: false),
            child: _TapTarget(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: state.pressed ? widget.pressedScale : 1,
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    child: widget.builder(context, state),
                  ),
                  Positioned(
                    left: -4,
                    top: -4,
                    right: -4,
                    bottom: -4,
                    child: ShelfFocusRing(
                      visible: state.focused,
                      borderRadius: widget.borderRadius + 2,
                      color: tokens.accent,
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

/// A 2 px focus ring that fills its parent: it fades in and settles from a
/// slightly larger size when [visible] turns on, so the focus glides from one
/// control to the next on a gamepad or keyboard, and fades out when it turns
/// off. Nothing is drawn once it is gone, and it does not move under the
/// system setting for less motion. Below a [FocusGlideHost] (a phone or
/// handheld) it draws nothing itself and hands its place to the one ring of
/// the host, which glides there.
class ShelfFocusRing extends StatefulWidget {
  const ShelfFocusRing({
    required this.visible,
    required this.borderRadius,
    required this.color,
    super.key,
  });

  final bool visible;
  final double borderRadius;
  final Color color;

  @override
  State<ShelfFocusRing> createState() => _ShelfFocusRingState();
}

const _ringFade = Duration(milliseconds: 160);

class _ShelfFocusRingState extends State<ShelfFocusRing>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _ringFade,
    value: widget.visible ? 1 : 0,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final _scale = Tween<double>(begin: 1.08, end: 1).animate(_curve);
  late final _source = GlideSource(
    context: context,
    radius: widget.borderRadius,
    color: widget.color,
  );
  FocusGlideHostState? _glide;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final glide = FocusGlideHost.maybeOf(context);
    if (glide == _glide) return;
    _glide?.release(_source);
    _glide = glide;
    if (widget.visible) glide?.claim(_source);
  }

  @override
  void didUpdateWidget(ShelfFocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _source
      ..radius = widget.borderRadius
      ..color = widget.color;
    if (oldWidget.visible == widget.visible) return;
    final glide = _glide;
    if (glide != null) {
      if (widget.visible) {
        glide.claim(_source);
      } else {
        glide.release(_source);
      }
    } else if (MediaQuery.of(context).disableAnimations) {
      _controller.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      unawaited(_controller.forward());
    } else {
      unawaited(_controller.reverse());
    }
  }

  @override
  void dispose() {
    _glide?.release(_source);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_glide != null) return const SizedBox.expand();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          _controller.isDismissed ? const SizedBox.shrink() : child!,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _curve,
          child: ScaleTransition(
            scale: _scale,
            child: DecoratedBox(
              key: const Key('focus-ring'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(color: widget.color, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// On a touch screen ([ShelfFormFactor.isTouch]) the tappable area around
/// [child] is at least [ShelfFormFactor.minTapTarget] square; the look keeps
/// its size and stays centred. Elsewhere the child is left as it is.
class _TapTarget extends StatelessWidget {
  const _TapTarget({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ShelfFormFactor.isTouch(context)) return child;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: ShelfFormFactor.minTapTarget,
        minHeight: ShelfFormFactor.minTapTarget,
      ),
      child: Align(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
