import 'dart:async';

import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/color_picker.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/features/appearance/theme_actions.dart';
import 'package:backlog_manager/features/appearance/theme_preview.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _gutter = 28.0;

/// The colours the palette of a colour picker offers: those of the built-in
/// themes.
final _palette = {
  for (final theme in builtinThemes)
    for (final field in ThemeColorField.values) theme.colors.colorOf(field),
}.toList();

/// The appearance screen: the built-in themes and the user's own, a form to
/// create or edit a theme and a live preview. The whole app repaints with the
/// colours being edited until the screen is left or the theme is saved.
class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  final _name = TextEditingController();
  final _hex = {
    for (final field in ThemeColorField.values) field: TextEditingController(),
  };
  late final ThemePreviewNotifier _preview;
  String? _editingId;
  late ThemeColors _colors;
  late ThemeColors _baseline;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _preview = ref.read(themePreviewProvider.notifier);
    final active = resolveTheme(
      ref.read(themeIdProvider),
      ref.read(customThemesProvider),
    );
    _colors = active.colors;
    _baseline = active.colors;
    _syncFields();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(shellStatusProvider.notifier).update(counts: 'Appearance');
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _hex.values) {
      controller.dispose();
    }
    scheduleMicrotask(_preview.clear);
    super.dispose();
  }

  void _syncFields() {
    for (final field in ThemeColorField.values) {
      _hex[field]!.text = _colors.colorOf(field);
    }
  }

  void _setColors(ThemeColors colors, {bool syncFields = false}) {
    setState(() => _colors = colors);
    if (syncFields) _syncFields();
    _preview.set(colors.isValid ? colors : null);
  }

  void _toast(String message) {
    if (mounted) showShelfToast(context, message);
  }

  void _startNew(ThemeColors base) {
    setState(() {
      _editingId = null;
      _baseline = base;
      _name.clear();
    });
    _setColors(base, syncFields: true);
  }

  void _startEditing(CustomTheme theme) {
    setState(() {
      _editingId = theme.id;
      _baseline = theme.colors;
      _name.text = theme.name;
    });
    _setColors(theme.colors, syncFields: true);
  }

  void _reset() {
    final custom = ref
        .read(customThemesProvider)
        .where((theme) => theme.id == _editingId)
        .firstOrNull;
    setState(() {
      if (custom != null) _name.text = custom.name;
    });
    _setColors(_baseline, syncFields: true);
  }

  Future<void> _save() async {
    final custom = ref.read(customThemesProvider);
    final name = _name.text.trim();
    if (!canSaveTheme(
      name: name,
      colors: _colors,
      customCount: custom.length,
      editing: _editingId != null,
    )) {
      return;
    }
    final id =
        _editingId ??
        newCustomThemeId([
          for (final theme in builtinThemes) theme.id,
          for (final theme in custom) theme.id,
        ]);
    setState(() => _saving = true);
    final error = await ref
        .read(themeActionsProvider)
        .saveCustom(CustomTheme(id: id, name: name, colors: _colors));
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      _toast(error);
      return;
    }
    setState(() {
      _editingId = id;
      _baseline = _colors;
    });
    _preview.set(null);
    _toast(themeSavedMessage(name));
  }

  Future<void> _delete(CustomTheme theme) async {
    final error = await ref.read(themeActionsProvider).deleteCustom(theme.id);
    if (!mounted) return;
    if (error != null) {
      _toast(error);
      return;
    }
    if (_editingId == theme.id) _startNew(_colors);
    _toast(themeDeletedMessage(theme.name));
  }

  Future<void> _select(String id) async {
    _preview.set(null);
    final error = await ref.read(themeActionsProvider).setTheme(id);
    if (error != null) _toast(error);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final custom = ref.watch(customThemesProvider);
    final activeId = ref.watch(themeIdProvider);
    final editing = _editingId != null;
    final canSave = canSaveTheme(
      name: _name.text,
      colors: _colors,
      customCount: custom.length,
      editing: editing,
    );
    final atLimit = !editing && custom.length >= maxCustomThemes;

    return Column(
      key: const Key('page-appearance'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Changes preview live across the whole app.',
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ),
              ShelfButton(
                key: const Key('theme-reset'),
                label: 'Reset',
                kind: ShelfButtonKind.quiet,
                onPressed: _reset,
              ),
              const SizedBox(width: 8),
              if (editing) ...[
                ShelfButton(
                  key: const Key('theme-new'),
                  label: 'New theme',
                  icon: Icons.add,
                  onPressed: () => _startNew(_colors),
                ),
                const SizedBox(width: 8),
              ],
              ShelfButton(
                key: const Key('theme-save'),
                label: editing ? 'Save changes' : 'Save theme',
                kind: ShelfButtonKind.primary,
                busy: _saving,
                onPressed: canSave && !_saving
                    ? () => unawaited(_save())
                    : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 250,
                  child: _themeList(custom, activeId, tokens, style),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 360,
                  child: _editor(editing, atLimit, tokens, style),
                ),
                const SizedBox(width: 20),
                const Expanded(child: ThemePreview()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _themeList(
    List<CustomTheme> custom,
    String activeId,
    ShelfTokens tokens,
    ShelfTextStyles style,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sideLabel('Built-in'),
        for (final theme in displayThemes)
          _ThemeItem(
            key: Key('theme-item-${theme.id}'),
            id: theme.id,
            name: theme.name,
            colors: theme.colors,
            active: theme.id == activeId,
            onSelect: () => unawaited(_select(theme.id)),
          ),
        const SizedBox(height: 10),
        _sideLabel('Your themes'),
        if (custom.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'No custom themes yet.',
              key: const Key('theme-none'),
              style: style.caption.copyWith(color: tokens.muted),
            ),
          ),
        for (final theme in custom)
          _ThemeItem(
            key: Key('theme-item-${theme.id}'),
            id: theme.id,
            name: theme.name,
            colors: theme.colors,
            active: theme.id == activeId,
            onSelect: () => unawaited(_select(theme.id)),
            onEdit: () => _startEditing(theme),
            onDelete: () => unawaited(_delete(theme)),
          ),
      ],
    );
  }

  Widget _sideLabel(String text) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(text.toUpperCase(), style: style.sidebarLabel),
    );
  }

  Widget _editor(
    bool editing,
    bool atLimit,
    ShelfTokens tokens,
    ShelfTextStyles style,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfFormGroup(
          title: editing ? 'Edit theme' : 'New theme',
          rows: [
            ShelfFormRow(
              label: 'Name',
              control: SizedBox(
                width: 200,
                height: ShelfHeight.input,
                child: TextField(
                  key: const Key('theme-name'),
                  controller: _name,
                  maxLength: themeNameMaxLength,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => null,
                  onChanged: (_) => setState(() {}),
                  style: style.fieldText,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Neon Night',
                  ),
                ),
              ),
            ),
            ShelfFormRow(
              label: 'Start from',
              control: SizedBox(
                width: 200,
                child: ShelfMenuAnchor(
                  entries: [
                    for (final theme in displayThemes)
                      ShelfMenuItem(
                        label: theme.name,
                        onSelected: () =>
                            _setColors(theme.colors, syncFields: true),
                      ),
                  ],
                  builder: (context, menu) => ShelfSelectTrigger(
                    key: const Key('theme-start-from'),
                    text: 'Choose a theme',
                    placeholder: true,
                    semanticLabel: 'Start from',
                    onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                  ),
                ),
              ),
            ),
            for (final field in ThemeColorField.values) _colorRow(field),
          ],
        ),
        if (atLimit) ...[
          const SizedBox(height: 10),
          Text(
            themeLimitMessage,
            key: const Key('theme-limit'),
            style: style.caption.copyWith(color: tokens.danger),
          ),
        ],
      ],
    );
  }

  Widget _colorRow(ThemeColorField field) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final value = _colors.colorOf(field);
    final valid = isHexColor(value);
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return ShelfFormRow(
      label: field.label,
      description: valid ? field.hint : 'Use a colour like #1a2b3c',
      control: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShelfColorPicker(
            value: valid ? value : '#000000',
            palette: _palette,
            label: '${field.label} colour',
            onChanged: (hex) =>
                _setColors(_colors.withColor(field, hex), syncFields: true),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            height: ShelfHeight.input,
            child: TextField(
              key: Key('theme-hex-${field.name}'),
              controller: _hex[field],
              maxLength: 7,
              buildCounter: (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => null,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
              ],
              onChanged: (text) => _setColors(_colors.withColor(field, text)),
              style: style.fieldText.copyWith(fontFamily: 'monospace'),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                enabledBorder: valid
                    ? null
                    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ShelfRadius.control,
                        ),
                        borderSide: BorderSide(color: tokens.danger),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem({
    required this.id,
    required this.name,
    required this.colors,
    required this.active,
    required this.onSelect,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final String id;
  final String name;
  final ThemeColors colors;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? tokens.accentSoft : tokens.surface,
          borderRadius: BorderRadius.circular(ShelfRadius.control),
          border: Border.all(
            color: active ? tokens.accent : tokens.borderSubtle,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ShelfPressable(
                  semanticLabel: active ? '$name, active' : name,
                  onPressed: onSelect,
                  borderRadius: ShelfRadius.control,
                  builder: (context, state) => Row(
                    children: [
                      ThemeSwatch(colors: colors),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.label,
                        ),
                      ),
                      if (active)
                        const ShelfChip(
                          label: 'active',
                          kind: ShelfChipKind.accent,
                        ),
                    ],
                  ),
                ),
              ),
              if (onEdit != null)
                ShelfIconButton(
                  key: Key('theme-edit-$id'),
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit $name',
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                ShelfIconButton(
                  key: Key('theme-delete-$id'),
                  icon: Icons.delete_outline,
                  tooltip: 'Delete $name',
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three colours of a theme in a small box: background, with the accent
/// and the glow in the corner.
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({required this.colors, super.key});

  final ThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorFromHex(colors.background),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorFromHex(colors.border)),
      ),
      child: SizedBox(
        width: 34,
        height: 26,
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorFromHex(colors.accent),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const SizedBox(width: 12, height: 6),
            ),
          ),
        ),
      ),
    );
  }
}
