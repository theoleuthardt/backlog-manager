import 'dart:async';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/spinner.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/creation_form.dart';
import 'package:backlog_manager/domain/inspector_logic.dart';
import 'package:backlog_manager/domain/platform_choices.dart';
import 'package:backlog_manager/features/achievements/achievement_progress.dart';
import 'package:backlog_manager/features/add_game/cover_picker_sheet.dart';
import 'package:backlog_manager/features/common/category_picker.dart';
import 'package:backlog_manager/features/common/status_select.dart';
import 'package:backlog_manager/features/creation/creation_draft.dart';
import 'package:backlog_manager/features/creation/foldable_about.dart';
import 'package:backlog_manager/features/inspector/inspector_parts.dart';
import 'package:backlog_manager/features/inspector/manage_platforms_sheet.dart';
import 'package:backlog_manager/features/inspector/mods_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the form of a draft shows of the Steam lookups: the lookup of the
/// Steam App ID by the title, the App ID shown (typed or looked up), the
/// playtime of the Steam account for it and the playtime of the form.
typedef DraftLookups = ({
  AsyncValue<int?> lookup,
  String steamAppId,
  AsyncValue<double?> steamHours,
  String playtime,
});

/// [DraftLookups] of [draft], watched so the form follows the lookups.
DraftLookups draftLookups(WidgetRef ref, CreationDraft draft) {
  final lookup = draft.lookupApplies
      ? ref.watch(steamAppIdProvider(draft.title.text.trim()))
      : const AsyncValue<int?>.data(null);
  final steamAppId = draft.steamAppIdTyped ?? lookup.value?.toString() ?? '';
  final appId = resolvedSteamAppId(steamAppId);
  final steamHours = appId == null
      ? const AsyncValue<double?>.data(null)
      : ref.watch(steamPlaytimeProvider(appId));
  return (
    lookup: lookup,
    steamAppId: steamAppId,
    steamHours: steamHours,
    playtime: effectivePlaytime(
      touched: draft.playtimeTouched,
      typed: draft.playtime.text,
      fromSteam: steamHours.value,
    ),
  );
}

/// The form of one game of the creation tool: cover, game info, your take,
/// the HowLongToBeat times, Steam, review and notes, and mods, all held by
/// [draft]. The status and the target show [fallbackStatus] and
/// [fallbackTarget] until the user chooses them for this game. [onSearchAgain]
/// shows "Search Again" under the cover.
class CreationGameForm extends ConsumerStatefulWidget {
  const CreationGameForm({
    required this.draft,
    required this.fallbackStatus,
    required this.fallbackTarget,
    this.busy = false,
    this.onSearchAgain,
    super.key,
  });

  final CreationDraft draft;
  final String fallbackStatus;
  final CreationTarget fallbackTarget;
  final bool busy;
  final VoidCallback? onSearchAgain;

  @override
  ConsumerState<CreationGameForm> createState() => _CreationGameFormState();
}

class _CreationGameFormState extends ConsumerState<CreationGameForm> {
  CreationDraft get _d => widget.draft;

  void _update(VoidCallback change) {
    change();
    _d.changed();
  }

  int? get _activeSpaceId => ref.read(activeSpaceIdProvider);

  CreationTarget get _target => _activeSpaceId == null
      ? CreationTarget.personal
      : _d.target(widget.fallbackTarget);

  List<int?> get _scopes => _target.scopes(_activeSpaceId);

  int? get _targetSpaceId =>
      _target == CreationTarget.space ? _activeSpaceId : null;

  String get _status => _d.status(widget.fallbackStatus);

  late DraftLookups _lookups;

  bool get _lookupApplies => _d.lookupApplies;

  AsyncValue<int?> get _lookup => _lookups.lookup;

  AsyncValue<double?> get _steamHours => _lookups.steamHours;

  int? get _resolvedAppId => resolvedSteamAppId(_lookups.steamAppId);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _d,
      builder: (context, _) {
        final tokens = Theme.of(context).extension<ShelfTokens>()!;
        final style = Theme.of(context).extension<ShelfTextStyles>()!;
        ref.watch(activeSpaceIdProvider);
        _lookups = draftLookups(ref, _d);
        if (_d.steamAppIdTyped == null) {
          _syncText(_d.steamAppId, _lookups.steamAppId);
        }
        if (!_d.playtimeTouched) _syncText(_d.playtime, _lookups.playtime);
        final lookingUp = _lookupApplies && _lookup.isLoading;
        final custom = _d.prefill.custom;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!custom && _d.prefill.hasMissingData)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WarningBanner(message: _d.prefill.missingDataMessage),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 920;
                final left = _leftColumn(tokens, style, wide: wide);
                final middle = _middleColumn(lookingUp);
                final right = _rightColumn(custom);
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left,
                      const SizedBox(height: 16),
                      middle,
                      const SizedBox(height: 16),
                      right,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 190, child: left),
                    const SizedBox(width: 24),
                    Expanded(child: middle),
                    const SizedBox(width: 24),
                    Expanded(child: right),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _otherPlatform() async {
    final chosen = await showManagePlatformsSheet(
      context,
      initial: _d.platforms,
      inBacklog: [
        ..._d.prefill.platformOptions,
        ...ref.read(filterOptionsProvider).platforms,
      ],
    );
    if (chosen != null && mounted) _update(() => _d.platforms = chosen);
  }

  Future<void> _addMod() async {
    final mod = await showModSheet(context);
    if (mod != null && mounted) _update(() => _d.mods = [..._d.mods, mod]);
  }

  Future<void> _changeCover() async {
    final url = await showCoverPicker(
      context,
      initialQuery: _d.title.text.trim(),
      steamAppId: _resolvedAppId,
    );
    if (url != null && mounted) _update(() => _d.imageUrl.text = url);
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.text != value) controller.text = value;
    });
  }

  /// The cover with "Search Again", "Change Cover" and the About text: a
  /// column of its own next to the form when it is [wide], else a small
  /// cover with the buttons beside it above the form, so the cover never
  /// takes the whole width of a phone or a handheld.
  Widget _leftColumn(
    ShelfTokens tokens,
    ShelfTextStyles style, {
    required bool wide,
  }) {
    final serverUrl = ref.watch(serverUrlProvider).value;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _d.imageUrl,
      builder: (context, value, _) {
        final cover = ShelfCover(
          title: _d.title.text.trim().isEmpty
              ? 'New Game'
              : _d.title.text.trim(),
          image: entryImage(serverUrl, value.text.trim()),
        );
        final buttons = <Widget>[
          if (widget.onSearchAgain != null) ...[
            ShelfButton(
              key: const Key('creation-search-again'),
              label: 'Search Again',
              onPressed: widget.busy ? null : widget.onSearchAgain,
            ),
            const SizedBox(height: 10),
          ],
          ShelfButton(
            key: const Key('creation-change-cover'),
            label: 'Change Cover',
            onPressed: _changeCover,
          ),
        ];
        final about = [
          if (_d.prefill.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('About', style: style.label),
            const SizedBox(height: 4),
            FoldableAbout(text: _d.prefill.description),
          ],
        ];
        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cover, const SizedBox(height: 10), ...buttons, ...about],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: _compactCoverWidth, child: cover),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: buttons,
                  ),
                ),
              ],
            ),
            ...about,
          ],
        );
      },
    );
  }

  Widget _field(
    Key key,
    TextEditingController controller, {
    String? hint,
    bool number = false,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    double width = 220,
  }) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return SizedBox(
      width: width,
      height: ShelfFormFactor.heightFor(context, ShelfHeight.input),
      child: TextField(
        key: key,
        controller: controller,
        enabled: enabled,
        onChanged: (value) {
          _update(() {});
          onChanged?.call(value);
        },
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        inputFormatters: number
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        style: style.fieldText,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }

  Widget _row(String label, Widget control, {String? description}) {
    return ShelfFormRow(
      label: label,
      description: description,
      control: control,
    );
  }

  Widget _platformControl() {
    final choices = platformChoices(
      selected: [..._d.prefill.platformOptions, ..._d.platforms],
      inBacklog: ref.watch(filterOptionsProvider).platforms,
    );
    bool chosen(String name) =>
        _d.platforms.any((known) => known.toLowerCase() == name.toLowerCase());
    return SizedBox(
      width: 220,
      child: ShelfMenuAnchor(
        entries: [
          for (final option in choices)
            ShelfMenuItem(
              itemKey: Key('creation-platform-$option'),
              label: option,
              checked: chosen(option),
              keepOpen: true,
              onSelected: () => _update(
                () => _d.platforms = togglePlatform(_d.platforms, option),
              ),
            ),
          const ShelfMenuDivider(),
          ShelfMenuItem(
            itemKey: const Key('creation-platform-other'),
            label: 'Other platform...',
            icon: Icons.add,
            onSelected: () => unawaited(_otherPlatform()),
          ),
        ],
        builder: (context, controller) => ShelfSelectTrigger(
          key: const Key('creation-platform'),
          text: _d.platforms.isEmpty
              ? 'Select platforms'
              : _d.platforms.join(', '),
          placeholder: _d.platforms.isEmpty,
          semanticLabel: 'Platform',
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }

  Widget _categoryRow(int? scope, {required String label, required Key key}) {
    return _row(
      label,
      SizedBox(
        width: 300,
        child: CategoryPicker.pending(
          key: key,
          spaceId: scope,
          selected: _d.categories[scope] ?? const {},
          onSelectedChanged: (ids) => _update(() => _d.categories[scope] = ids),
        ),
      ),
    );
  }

  String get _targetLabel => switch (_target) {
    CreationTarget.personal => 'My Backlog',
    CreationTarget.space => 'Shared Space',
    CreationTarget.both => 'Both',
  };

  Widget _middleColumn(bool lookingUp) {
    final steamHours = _steamHours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfFormGroup(
          title: 'Game Info',
          rows: [
            if (_activeSpaceId != null)
              _row(
                'Add to',
                SizedBox(
                  width: 220,
                  child: ShelfMenuAnchor(
                    entries: [
                      for (final (target, label) in [
                        (CreationTarget.personal, 'My Backlog'),
                        (CreationTarget.space, 'Shared Space'),
                        (CreationTarget.both, 'Both'),
                      ])
                        ShelfMenuItem(
                          label: label,
                          checked: _target == target,
                          onSelected: () =>
                              _update(() => _d.targetChosen = target),
                        ),
                    ],
                    builder: (context, controller) => ShelfSelectTrigger(
                      key: const Key('creation-target'),
                      text: _targetLabel,
                      semanticLabel: 'Add to',
                      onPressed: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                    ),
                  ),
                ),
              ),
            _row(
              'Title',
              _field(
                const Key('creation-title'),
                _d.title,
                enabled: _d.prefill.custom,
              ),
            ),
            _row('Platform', _platformControl()),
            _row(
              'Genre',
              _field(
                const Key('creation-genre'),
                _d.genre,
                hint: 'Action, RPG, Adventure',
              ),
            ),
            _row(
              'Publisher',
              _field(
                const Key('creation-publisher'),
                _d.publisher,
                hint: 'The company that published the game',
              ),
            ),
            if (_d.prefill.custom)
              _row(
                'Image URL',
                _field(
                  const Key('creation-image-url'),
                  _d.imageUrl,
                  hint: 'https://example.com/cover.jpg',
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ShelfFormGroup(
          title: 'Your Take',
          rows: [
            _row(
              'Status',
              SizedBox(
                width: 220,
                child: StatusSelect(
                  spaceId: _targetSpaceId,
                  value: _status,
                  onChanged: (status) =>
                      _update(() => _d.statusChosen = status),
                ),
              ),
            ),
            for (final scope in _scopes)
              _categoryRow(
                scope,
                label: _scopes.length > 1
                    ? scope == null
                          ? 'Categories (My Backlog)'
                          : 'Categories (Shared Space)'
                    : 'Categories',
                key: Key(
                  scope == null
                      ? 'creation-categories'
                      : _scopes.length > 1
                      ? 'creation-categories-space'
                      : 'creation-categories',
                ),
              ),
            _row(
              'Interest',
              SizedBox(
                width: 300,
                child: InterestPicker(
                  value: _d.interest,
                  onChanged: (value) => _update(() => _d.interest = value),
                ),
              ),
            ),
            _row(
              'Playtime (h)',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (steamHours.isLoading && !_d.playtimeTouched)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        key: Key('creation-playtime-loading'),
                        width: 20,
                        height: 20,
                        child: ShelfSpinner(size: 20),
                      ),
                    ),
                  _field(
                    const Key('creation-playtime'),
                    _d.playtime,
                    number: true,
                    width: 120,
                    onChanged: (_) => _d.playtimeTouched = true,
                  ),
                ],
              ),
            ),
            _row(
              'I own this game',
              ShelfSwitch(
                key: const Key('creation-owned'),
                value: _d.owned,
                label: 'I own this game',
                onChanged: (value) => _update(() => _d.owned = value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rightColumn(bool custom) {
    final lookingUp = _lookupApplies && _lookup.isLoading;
    final reviewable = canReview(_status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfFormGroup(
          title: 'HowLongToBeat Times',
          description: custom
              ? null
              : _d.prefill.hasHltbData
              ? 'Times from HowLongToBeat - editable for custom games only.'
              : 'Editable because no match was found.',
          rows: [
            _row(
              'Main',
              _field(
                const Key('creation-main'),
                _d.mainStory,
                number: true,
                enabled: custom || !_d.prefill.hasHltbData,
                width: 120,
              ),
            ),
            _row(
              'Main + Extra',
              _field(
                const Key('creation-extra'),
                _d.mainStoryWithExtras,
                number: true,
                enabled: custom || !_d.prefill.hasHltbData,
                width: 120,
              ),
            ),
            _row(
              'Completionist',
              _field(
                const Key('creation-completionist'),
                _d.completionist,
                number: true,
                enabled: custom || !_d.prefill.hasHltbData,
                width: 120,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ShelfFormGroup(
          title: 'Steam',
          rows: [
            _row(
              'App ID',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lookingUp)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        key: Key('creation-lookup-loading'),
                        width: 20,
                        height: 20,
                        child: ShelfSpinner(size: 20),
                      ),
                    ),
                  _field(
                    const Key('creation-steam-app-id'),
                    _d.steamAppId,
                    number: true,
                    width: 160,
                    hint: custom
                        ? 'e.g. 504230'
                        : lookingUp
                        ? 'Looking up on Steam...'
                        : 'No Steam App ID found',
                    onChanged: (value) => _d.steamAppIdTyped = value,
                  ),
                ],
              ),
            ),
            if (_resolvedAppId != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: AchievementProgressSection(steamAppId: _resolvedAppId),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ShelfFormGroup(
          title: 'Review & notes',
          rows: [
            _row(
              'Review Stars',
              Tooltip(
                message: reviewable ? '' : _needsCompleted,
                child: Opacity(
                  opacity: reviewable ? 1 : 0.5,
                  child: StarRating(
                    value: _d.reviewStars,
                    onChanged: reviewable
                        ? (value) => _update(() => _d.reviewStars = value)
                        : null,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Tooltip(
                message: reviewable ? '' : _needsCompleted,
                child: ShelfTextArea(
                  label: 'Review',
                  fieldKey: const Key('creation-review'),
                  controller: _d.review,
                  enabled: reviewable,
                  minLines: 3,
                  hintText: reviewable
                      ? 'Write your review here...'
                      : 'Set the status to Completed to write a review',
                  onChanged: (_) {},
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ShelfTextArea(
                label: 'Notes',
                fieldKey: const Key('creation-note'),
                controller: _d.note,
                minLines: 3,
                hintText: 'Add any notes about this game...',
                onChanged: (_) {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ShelfFormGroup(
          title: 'Mods',
          description: 'Added to the game once it is created.',
          rows: [
            for (final (index, mod) in _d.mods.indexed)
              _row(
                mod.name,
                ShelfButton(
                  key: Key('creation-mod-remove-$index'),
                  label: 'Remove',
                  kind: ShelfButtonKind.quiet,
                  onPressed: () =>
                      _update(() => _d.mods = [..._d.mods]..removeAt(index)),
                ),
                description: mod.url,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ShelfButton(
                  key: const Key('mod-add'),
                  label: 'Add mod',
                  icon: Icons.add,
                  onPressed: () => unawaited(_addMod()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

const _needsCompleted = 'Stars and review need the status Completed';

/// The width of the cover above the form on a phone or a handheld.
const _compactCoverWidth = 128.0;

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return DecoratedBox(
      key: const Key('creation-warning'),
      decoration: BoxDecoration(
        color: atOpacity(tokens.accent, 0.12),
        borderRadius: BorderRadius.circular(ShelfRadius.control),
        border: Border.all(color: atOpacity(tokens.accent, 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: tokens.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warning: Missing game data',
                    style: style.control.copyWith(color: tokens.accent),
                  ),
                  Text(
                    message,
                    style: style.caption.copyWith(color: tokens.text2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
