import 'dart:async';

import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:flutter/material.dart';

/// A short message on `surface2` with an optional action such as "Undo".
class ShelfToast extends StatelessWidget {
  const ShelfToast({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      key: const Key('toast-surface'),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderStrong),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC000000),
            blurRadius: 48,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: text.control.copyWith(color: tokens.foreground),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 16),
              ShelfPressable(
                onPressed: onAction,
                semanticLabel: actionLabel,
                borderRadius: 6,
                builder: (context, state) => Text(
                  actionLabel!,
                  style: text.control.copyWith(color: tokens.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A toast that is showing; [dismiss] removes it before its time is up.
class ShelfToastHandle {
  ShelfToastHandle._(this._entry, this._timer);

  final OverlayEntry _entry;
  final Timer _timer;
  bool _gone = false;

  void dismiss() {
    if (_gone) return;
    _gone = true;
    _timer.cancel();
    _entry.remove();
    _entry.dispose();
    if (identical(_current, this)) _current = null;
  }
}

ShelfToastHandle? _current;

/// Shows a toast above the status bar. Only one toast shows at a time; a new
/// one replaces the one still on screen.
ShelfToastHandle showShelfToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 5),
}) {
  _current?.dismiss();
  final overlay = Overlay.of(context, rootOverlay: true);
  late final ShelfToastHandle handle;
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 0,
      right: 0,
      bottom: 44,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: ShelfToast(
            message: message,
            actionLabel: actionLabel,
            onAction: onAction == null
                ? null
                : () {
                    onAction();
                    handle.dismiss();
                  },
          ),
        ),
      ),
    ),
  );
  handle = ShelfToastHandle._(entry, Timer(duration, () => handle.dismiss()));
  overlay.insert(entry);
  _current = handle;
  return handle;
}
