import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

/// A 36 px search field on `surface2` with the magnifier in front.
class ShelfSearchInput extends StatelessWidget {
  const ShelfSearchInput({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    return SizedBox(
      height: ShelfHeight.input + 2,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textAlignVertical: TextAlignVertical.center,
        style: text.fieldText.copyWith(fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, size: 16, color: tokens.faint),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
        ),
      ),
    );
  }
}
