import 'package:flutter/widgets.dart';

/// Whether the app runs on a phone in portrait, set once above the navigator
/// (so sheets and dialogs see it too) from the layout of the shell. The UI kit
/// reads it instead of the screen width: a narrow desktop window or a golden
/// test of a single component is never a phone, and without a
/// [ShelfFormFactor] above it a widget keeps its desktop form.
class ShelfFormFactor extends InheritedWidget {
  const ShelfFormFactor({
    required this.compact,
    required super.child,
    super.key,
  });

  /// A phone in portrait: rows stack, sheets rise from the bottom, keyboard
  /// hints are left out.
  final bool compact;

  /// The [compact] of the nearest [ShelfFormFactor], false without one.
  static bool isCompact(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShelfFormFactor>()?.compact ??
      false;

  @override
  bool updateShouldNotify(ShelfFormFactor oldWidget) =>
      compact != oldWidget.compact;
}
