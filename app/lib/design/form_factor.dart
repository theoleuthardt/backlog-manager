import 'package:flutter/widgets.dart';

/// Whether the app runs on a touch screen (Android, iOS) and on a phone in
/// portrait, set once above the navigator (so sheets and dialogs see it too)
/// from the platform and the layout of the shell. The UI kit
/// reads it instead of the screen width: a narrow desktop window or a golden
/// test of a single component is never a phone, and without a
/// [ShelfFormFactor] above it a widget keeps its desktop form.
class ShelfFormFactor extends InheritedWidget {
  const ShelfFormFactor({
    required this.compact,
    required super.child,
    this.touch = false,
    super.key,
  });

  /// A touch screen: every tap target is at least [minTapTarget] square.
  final bool touch;

  /// The smallest tap target on a touch screen, after the Android and iOS
  /// guidelines (48 dp, 44 pt).
  static const minTapTarget = 48.0;

  /// A phone in portrait: rows stack, sheets rise from the bottom, keyboard
  /// hints are left out.
  final bool compact;

  /// The [compact] of the nearest [ShelfFormFactor], false without one.
  static bool isCompact(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShelfFormFactor>()?.compact ??
      false;

  /// [height] on the desktop; on a touch screen at least [minTapTarget], for
  /// the fixed heights of controls and of the rows that hold them.
  /// Whether a field that a sheet or page opens with takes the focus at
  /// once: not on a touch screen lower than 600 px (a handheld or a phone in
  /// landscape), where the on-screen keyboard would cover all of it before
  /// the user even sees what opened.
  static bool autofocus(BuildContext context) =>
      !isTouch(context) || MediaQuery.sizeOf(context).height >= 600;

  static double heightFor(BuildContext context, double height) =>
      isTouch(context) && height < minTapTarget ? minTapTarget : height;

  /// The [touch] of the nearest [ShelfFormFactor], false without one.
  static bool isTouch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShelfFormFactor>()?.touch ??
      false;

  @override
  bool updateShouldNotify(ShelfFormFactor oldWidget) =>
      compact != oldWidget.compact || touch != oldWidget.touch;
}
