import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// A labelled text input: the label above in muted 12 px text, the 34 px input
/// on `surface2`, and below it either an [error] in the danger colour or a
/// [hint] in the faint colour.
class ShelfField extends StatelessWidget {
  const ShelfField({
    required this.label,
    this.hint,
    this.error,
    this.hintText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    super.key,
  });

  final String label;
  final String? hint;
  final String? error;
  final String? hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final note = error ?? hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.label.copyWith(color: tokens.muted)),
        const SizedBox(height: 6),
        SizedBox(
          height: ShelfHeight.input,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            obscureText: obscure,
            enabled: enabled,
            autofocus: autofocus,
            keyboardType: keyboardType,
            style: text.fieldText,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: hintText,
              enabledBorder: error == null
                  ? null
                  : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ShelfRadius.control),
                      borderSide: BorderSide(color: tokens.danger),
                    ),
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note,
            style: text.caption.copyWith(
              color: error == null ? tokens.faint : tokens.danger,
            ),
          ),
        ],
      ],
    );
  }
}

/// One row of a [ShelfFormGroup]: the label on the left (with a small
/// description below it) and the control on the right.
class ShelfFormRow extends StatelessWidget {
  const ShelfFormRow({
    required this.label,
    required this.control,
    this.description,
    super.key,
  });

  final String label;
  final String? description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.control.copyWith(color: tokens.foreground),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: text.caption.copyWith(color: tokens.faint),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }
}

/// A titled panel of [rows] on `surface`, separated by 1 px dividers; used for
/// settings, the creation tool and the column mapping.
class ShelfFormGroup extends StatelessWidget {
  const ShelfFormGroup({
    required this.title,
    required this.rows,
    this.description,
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return DecoratedBox(
      key: const Key('form-group-surface'),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(ShelfRadius.panel),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.groupTitle),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: text.caption.copyWith(color: tokens.muted),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              SizedBox(
                height: 1,
                child: ColoredBox(
                  key: const Key('form-row-divider'),
                  color: tokens.borderSubtle,
                ),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}
