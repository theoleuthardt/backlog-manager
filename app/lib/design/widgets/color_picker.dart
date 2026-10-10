import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';

/// The swatch of a colour as a button.
class ShelfColorSwatch extends StatelessWidget {
  const ShelfColorSwatch({
    required this.value,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String value;

  /// Read out by assistive technology.
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;

    return ShelfPressable(
      key: const Key('color-picker'),
      borderRadius: 8,
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, state) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: state.hovered ? tokens.glow : tokens.borderStrong,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            key: const Key('color-picker-swatch'),
            decoration: BoxDecoration(
              color: colorFromHex(value),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const SizedBox(width: 26, height: 26),
          ),
        ),
      ),
    );
  }
}

/// A swatch of the current colour that opens a palette and a field for a
/// `#rrggbb` value in a popover. [onChanged] gets lower-case `#rrggbb` text;
/// anything the field holds that is not a colour is ignored. Inside another
/// popover use [ShelfColorSwatch] and [ShelfColorPalette] inline instead, a
/// tap in a nested popover would close the outer one.
class ShelfColorPicker extends StatelessWidget {
  const ShelfColorPicker({
    required this.value,
    required this.palette,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final String value;
  final List<String> palette;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ShelfPopover(
      content: ShelfColorPalette(
        value: value,
        palette: palette,
        onChanged: onChanged,
      ),
      builder: (context, controller) => ShelfColorSwatch(
        value: value,
        label: label,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The palette of colours with the current one checked and a field for a
/// `#rrggbb` value.
class ShelfColorPalette extends StatefulWidget {
  const ShelfColorPalette({
    required this.value,
    required this.palette,
    required this.onChanged,
    super.key,
  });

  final String value;
  final List<String> palette;
  final ValueChanged<String> onChanged;

  @override
  State<ShelfColorPalette> createState() => _ShelfColorPaletteState();
}

class _ShelfColorPaletteState extends State<ShelfColorPalette> {
  late String _current = widget.value;
  late final TextEditingController _hex = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _pick(String hex) {
    setState(() {
      _current = hex;
      _hex.text = hex;
    });
    widget.onChanged(hex);
  }

  void _submit() {
    final text = _hex.text.trim().toLowerCase();
    if (isHexColor(text)) {
      _pick(text);
    } else {
      _hex.text = _current;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;

    return SizedBox(
      width: 200,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in widget.palette)
                  ShelfPressable(
                    key: Key('color-option-$hex'),
                    borderRadius: 8,
                    semanticLabel: 'Colour $hex',
                    onPressed: () => _pick(hex),
                    builder: (context, state) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorFromHex(hex),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: state.hovered
                              ? tokens.foreground
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: hex == _current
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: onColorFor(colorFromHex(hex)),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('color-hex-field'),
              controller: _hex,
              style: style.fieldText,
              decoration: const InputDecoration(hintText: '#rrggbb'),
              onSubmitted: (_) => _submit(),
              onTapOutside: (_) => _submit(),
            ),
          ],
        ),
      ),
    );
  }
}
