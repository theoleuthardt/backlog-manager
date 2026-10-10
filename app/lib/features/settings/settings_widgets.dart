import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:flutter/material.dart';

/// A text input for a row of a settings group. [onCommit] is called with the
/// text when the field loses the focus or Enter is pressed, for secrets that
/// are only worth sending once they are complete. Enter followed by a blur
/// calls it twice with the same text, so a caller must clear or ignore a text
/// it has already taken.
class SettingsTextField extends StatefulWidget {
  const SettingsTextField({
    required this.fieldKey,
    required this.controller,
    this.hintText,
    this.obscure = false,
    this.onChanged,
    this.onCommit,
    this.width = 240,
    super.key,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String? hintText;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCommit;
  final double width;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onCommit?.call(widget.controller.text);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return SizedBox(
      width: widget.width,
      height: ShelfHeight.input,
      child: TextField(
        key: widget.fieldKey,
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscure,
        onChanged: widget.onChanged,
        onSubmitted: widget.onCommit,
        style: style.fieldText,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(hintText: widget.hintText),
      ),
    );
  }
}

/// The control of a secret row: the input and, when a value is saved, a
/// "Remove" button.
class SecretControl extends StatelessWidget {
  const SecretControl({
    required this.fieldKey,
    required this.controller,
    required this.placeholder,
    required this.isSet,
    required this.onCommit,
    required this.onRemove,
    this.removeKey,
    super.key,
  });

  final Key fieldKey;
  final Key? removeKey;
  final TextEditingController controller;
  final String placeholder;
  final bool isSet;
  final ValueChanged<String> onCommit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsTextField(
          fieldKey: fieldKey,
          controller: controller,
          hintText: placeholder,
          obscure: true,
          onCommit: onCommit,
        ),
        if (isSet) ...[
          const SizedBox(width: 8),
          ShelfButton(key: removeKey, label: 'Remove', onPressed: onRemove),
        ],
      ],
    );
  }
}

/// A line of muted help text below a settings group.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(text, style: style.caption.copyWith(color: tokens.faint)),
    );
  }
}

/// The title and the line below it at the top of a settings tab.
class SettingsTabTitle extends StatelessWidget {
  const SettingsTabTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: style.page.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Text(subtitle, style: style.caption.copyWith(color: tokens.muted)),
        ],
      ),
    );
  }
}
