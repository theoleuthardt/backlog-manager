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
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final Widget Function(BuildContext context, ShelfInteraction state) builder;
  final VoidCallback? onPressed;

  /// The radius of the focus ring is this plus its offset.
  final double borderRadius;
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                widget.builder(context, state),
                if (state.focused)
                  Positioned(
                    left: -4,
                    top: -4,
                    right: -4,
                    bottom: -4,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const Key('focus-ring'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            widget.borderRadius + 2,
                          ),
                          border: Border.all(color: tokens.accent, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
