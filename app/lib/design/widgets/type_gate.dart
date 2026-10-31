import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A text field that a gamepad steps onto without typing in it, the way a TV
/// or a handheld does it: on a touch screen the D-pad stops on the gate (with
/// the focus ring) instead of the field, which would open the on-screen
/// keyboard at once, the full-screen one in landscape. A (or Enter) starts
/// typing, B (or Esc) stops typing and stays on the field, and a tap types at
/// once as before. [builder] builds the field with the focus node it has to
/// use: [focusNode] when given, otherwise one of the gate. The desktop has no
/// gate.
class TypeGate extends StatefulWidget {
  const TypeGate({
    required this.builder,
    this.focusNode,
    this.borderRadius = ShelfRadius.control,
    super.key,
  });

  final Widget Function(BuildContext context, FocusNode focusNode) builder;
  final FocusNode? focusNode;
  final double borderRadius;

  @override
  State<TypeGate> createState() => _TypeGateState();
}

class _TypeGateState extends State<TypeGate> {
  final _gate = FocusNode(debugLabel: 'TypeGate');
  FocusNode? _own;
  bool _gateFocused = false;

  FocusNode get _field =>
      widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'TypeGate field'));

  @override
  void initState() {
    super.initState();
    _gate.addListener(() {
      if (_gate.hasPrimaryFocus != _gateFocused) {
        setState(() => _gateFocused = _gate.hasPrimaryFocus);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _field.skipTraversal = ShelfFormFactor.isTouch(context);
  }

  @override
  void didUpdateWidget(TypeGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.skipTraversal = false;
      _field.skipTraversal = ShelfFormFactor.isTouch(context);
    }
  }

  @override
  void dispose() {
    widget.focusNode?.skipTraversal = false;
    _own?.dispose();
    _gate.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_gate.hasPrimaryFocus &&
        (key == LogicalKeyboardKey.gameButtonA ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select)) {
      _field.requestFocus();
      return KeyEventResult.handled;
    }
    if (_field.hasFocus &&
        (key == LogicalKeyboardKey.gameButtonB ||
            key == LogicalKeyboardKey.escape)) {
      _gate.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.builder(context, _field);
    if (!ShelfFormFactor.isTouch(context)) return field;
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return Focus(
      focusNode: _gate,
      onKeyEvent: _onKey,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          field,
          Positioned(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: ShelfFocusRing(
              visible: _gateFocused,
              borderRadius: widget.borderRadius + 2,
              color: tokens.accent,
            ),
          ),
        ],
      ),
    );
  }
}
