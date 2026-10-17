import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/platform_choices.dart';
import 'package:flutter/material.dart';

/// Opens "Manage Platforms" for a game that has the platforms [initial] and
/// returns the platforms the user ended with, or null when the sheet was
/// cancelled. [inBacklog] are the platforms of the whole backlog.
Future<List<String>?> showManagePlatformsSheet(
  BuildContext context, {
  required List<String> initial,
  required List<String> inBacklog,
}) {
  return showShelfSheet<List<String>>(
    context,
    builder: (_) =>
        ManagePlatformsSheet(initial: initial, inBacklog: inBacklog),
  );
}

/// Chooses the platforms of one game: a chip per platform of the backlog and
/// the common ones (a tap selects or deselects it), and a field for a
/// platform of its own. Nothing is saved until "Done".
class ManagePlatformsSheet extends StatefulWidget {
  const ManagePlatformsSheet({
    required this.initial,
    required this.inBacklog,
    super.key,
  });

  final List<String> initial;
  final List<String> inBacklog;

  @override
  State<ManagePlatformsSheet> createState() => _ManagePlatformsSheetState();
}

class _ManagePlatformsSheetState extends State<ManagePlatformsSheet> {
  late List<String> _selected = widget.initial;
  late final List<String> _choices = platformChoices(
    selected: widget.initial,
    inBacklog: widget.inBacklog,
  );
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isSelected(String name) =>
      _selected.any((known) => known.toLowerCase() == name.toLowerCase());

  void _add(String typed) {
    final next = addPlatform(_selected, typed);
    if (identical(next, _selected)) return;
    setState(() {
      _selected = next;
      final added = next.last;
      if (!_choices.any((c) => c.toLowerCase() == added.toLowerCase())) {
        _choices.add(added);
      }
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final error = _controller.text.contains(',')
        ? 'A platform name cannot have a comma'
        : null;
    return ShelfSheet(
      title: 'Manage Platforms',
      description: 'Tap a platform to add it to the game or to remove it.',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: () => Navigator.of(context).pop(),
        cancelLabel: 'Cancel',
        primary: ShelfButton(
          key: const Key('platforms-done'),
          label: 'Done',
          kind: ShelfButtonKind.primary,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in _choices)
                _PlatformChoice(
                  name: name,
                  selected: _isSelected(name),
                  onPressed: () => setState(
                    () => _selected = togglePlatform(_selected, name),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ShelfField(
                  key: const Key('platform-new'),
                  label: 'Add a platform of your own',
                  hintText: 'Amiga',
                  controller: _controller,
                  error: error,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _add,
                ),
              ),
              const SizedBox(width: 8),
              ShelfButton(
                key: const Key('platform-add'),
                label: 'Add',
                onPressed: () => _add(_controller.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlatformChoice extends StatelessWidget {
  const _PlatformChoice({
    required this.name,
    required this.selected,
    required this.onPressed,
  });

  final String name;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return ShelfPressable(
      key: Key('platform-choice-$name'),
      borderRadius: 8,
      semanticLabel: selected ? 'Remove $name' : 'Add $name',
      onPressed: onPressed,
      builder: (context, state) => DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : tokens.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? tokens.accent : tokens.borderStrong,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  Icons.check,
                  key: Key('platform-selected-$name'),
                  size: 14,
                  color: tokens.accent,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                name,
                style: style.label.copyWith(
                  color: selected ? tokens.foreground : tokens.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
