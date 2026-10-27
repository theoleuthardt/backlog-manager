import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// A labelled text input: the label above in muted text, the input on
/// `surface2`, and below it either an [error] in the danger colour or a [hint]
/// in the faint colour. An [obscure] field has a button at its right end that
/// shows or hides what was typed.
class ShelfField extends StatefulWidget {
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
    this.labelAction,
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

  /// A small control at the right end of the label line, for example "Manage".
  final Widget? labelAction;

  @override
  State<ShelfField> createState() => _ShelfFieldState();
}

class _ShelfFieldState extends State<ShelfField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final widget = this.widget;
    final error = widget.error;
    final note = error ?? widget.hint;
    final dangerBorder = error == null
        ? null
        : OutlineInputBorder(
            borderRadius: BorderRadius.circular(ShelfRadius.control),
            borderSide: BorderSide(color: tokens.danger),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: text.label.copyWith(color: tokens.muted),
              ),
            ),
            if (widget.labelAction != null) widget.labelAction!,
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: ShelfHeight.input,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            obscureText: widget.obscure && !_revealed,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            style: text.fieldText,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: widget.hintText,
              enabledBorder: dangerBorder,
              focusedBorder: dangerBorder,
              suffixIcon: widget.obscure
                  ? IconButton(
                      key: const Key('field-reveal'),
                      tooltip: _revealed ? 'Hide password' : 'Show password',
                      icon: Icon(
                        _revealed
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: tokens.muted,
                      ),
                      onPressed: () => setState(() => _revealed = !_revealed),
                    )
                  : null,
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
/// description below it) and the control on the right; on a phone in
/// portrait ([ShelfFormFactor]) the control goes below the label.
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
    final caption = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.control.copyWith(color: tokens.foreground)),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              description!,
              style: text.caption.copyWith(color: tokens.faint),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ShelfFormFactor.isCompact(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [caption, const SizedBox(height: 10), control],
            )
          : Row(
              children: [
                Expanded(child: caption),
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
