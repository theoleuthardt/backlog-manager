import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/data/entry_mod_providers.dart';
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
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/creation_form.dart';
import 'package:backlog_manager/domain/inspector_logic.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/platform_choices.dart';
import 'package:backlog_manager/features/achievements/achievement_progress.dart';
import 'package:backlog_manager/features/add_game/cover_picker_sheet.dart';
import 'package:backlog_manager/features/add_game/game_result_parts.dart';
import 'package:backlog_manager/features/common/category_picker.dart';
import 'package:backlog_manager/features/common/status_select.dart';
import 'package:backlog_manager/features/creation/duplicate_sheet.dart';
import 'package:backlog_manager/features/creation/foldable_about.dart';
import 'package:backlog_manager/features/inspector/inspector_parts.dart';
import 'package:backlog_manager/features/inspector/manage_platforms_sheet.dart';
import 'package:backlog_manager/features/inspector/mods_section.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _CreateState { idle, creating, created, failed }

/// The form for a new game: filled from a search result or empty for a custom
/// game. Everything the inspector sets on a game can be set here too: several
/// platforms (also ones of its own), the publisher, categories and mods, and
/// with an active Shared Space whether the game goes to the personal backlog,
/// the space or both. It checks for duplicates in each of them before it
/// creates the entries, then adds the categories and mods to each, and
/// returns to the library afterwards.
class CreationToolPage extends ConsumerStatefulWidget {
  const CreationToolPage({required this.query, super.key});

  /// The query of the address, see [CreationPrefill.fromQuery].
  final Map<String, String> query;

  @override
  ConsumerState<CreationToolPage> createState() => _CreationToolPageState();
}

class _CreationToolPageState extends ConsumerState<CreationToolPage> {
  late final CreationPrefill _prefill;
  late final TextEditingController _title;
  late final TextEditingController _genre;
  late final TextEditingController _publisher;
  late final TextEditingController _imageUrl;
  late final TextEditingController _playtime;
  late final TextEditingController _steamAppId;
  late final TextEditingController _mainStory;
  late final TextEditingController _mainStoryWithExtras;
  late final TextEditingController _completionist;
  late final TextEditingController _review;
  late final TextEditingController _note;
  String _status = '';
  int _interest = 5;
  bool _owned = false;
  int _reviewStars = 0;
  bool _playtimeTouched = false;
  String? _steamAppIdTyped;
  CreationTarget? _targetTyped;
  late List<String> _platforms;
  final Map<int?, Set<int>> _categories = {};
  List<ModInput> _mods = const [];
  _CreateState _state = _CreateState.idle;
  Timer? _leave;

  @override
  void initState() {
    super.initState();
    _prefill = CreationPrefill.fromQuery(widget.query);
    String hours(double value) =>
        value == value.roundToDouble() ? '${value.toInt()}' : '$value';
    _title = TextEditingController(text: _prefill.title);
    _genre = TextEditingController(text: _prefill.genres);
    _publisher = TextEditingController(text: _prefill.publisher);
    _platforms = [
      if (_prefill.defaultPlatform.isNotEmpty) _prefill.defaultPlatform,
    ];
    _imageUrl = TextEditingController(text: _prefill.imageUrl);
    _playtime = TextEditingController(text: '0');
    _steamAppId = TextEditingController();
    _mainStory = TextEditingController(text: hours(_prefill.mainStory));
    _mainStoryWithExtras = TextEditingController(
      text: hours(_prefill.mainStoryWithExtras),
    );
    _completionist = TextEditingController(text: hours(_prefill.completionist));
    _review = TextEditingController();
    _note = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(shellStatusProvider.notifier)
            .update(counts: 'New entry · not saved yet');
      }
    });
  }

  @override
  void dispose() {
    _leave?.cancel();
    for (final controller in [
      _title,
      _genre,
      _publisher,
      _imageUrl,
      _playtime,
      _steamAppId,
      _mainStory,
      _mainStoryWithExtras,
      _completionist,
      _review,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? get _activeSpaceId => ref.read(activeSpaceIdProvider);

  CreationTarget get _target {
    if (_activeSpaceId == null) return CreationTarget.personal;
    return _targetTyped ??
        (_prefill.targetsSpace
            ? CreationTarget.space
            : CreationTarget.personal);
  }

  List<int?> get _scopes => _target.scopes(_activeSpaceId);

  int? get _targetSpaceId =>
      _target == CreationTarget.space ? _activeSpaceId : null;

  String get _backTo =>
      _target == CreationTarget.space ? AppRoutes.space : AppRoutes.library;

  bool get _lookupApplies => !_prefill.custom && _prefill.title.isNotEmpty;

  AsyncValue<int?> get _lookup => _lookupApplies
      ? ref.watch(steamAppIdProvider(_title.text.trim()))
      : const AsyncData(null);

  String get _displayedSteamAppId =>
      _steamAppIdTyped ?? _lookup.value?.toString() ?? '';

  int? get _resolvedAppId => resolvedSteamAppId(_displayedSteamAppId);

  AsyncValue<double?> get _steamHours {
    final appId = _resolvedAppId;
    return appId == null
        ? const AsyncData(null)
        : ref.watch(steamPlaytimeProvider(appId));
  }

  String get _effectivePlaytime => effectivePlaytime(
    touched: _playtimeTouched,
    typed: _playtime.text,
    fromSteam: _steamHours.value,
  );

  CreationInput get _input => CreationInput(
    title: _title.text,
    genre: _genre.text,
    platform: _platforms.join(', '),
    status: _status,
    owned: _owned,
    interest: _interest,
    playtime: _effectivePlaytime,
    steamAppId: _displayedSteamAppId,
    imageUrl: _imageUrl.text,
    publisher: _publisher.text,
    mainStory: _mainStory.text,
    mainStoryWithExtras: _mainStoryWithExtras.text,
    completionist: _completionist.text,
    reviewStars: _reviewStars,
    review: _review.text,
    note: _note.text,
  );

  void _toast(String message) {
    if (mounted) showShelfToast(context, message);
  }

  Future<void> _submit() async {
    if (_state == _CreateState.creating || _state == _CreateState.created) {
      return;
    }
    final input = _input;
    final problem = validateCreation(input);
    if (problem != null) {
      _toast(problem);
      return;
    }
    final entry = buildNewEntry(input, _prefill);
    final scopes = _scopes;
    final backTo = _backTo;
    setState(() => _state = _CreateState.creating);
    try {
      final existing = [
        for (final scope in scopes)
          ...await ref
              .read(backlogApiProvider)
              .duplicates(entry.title, entry.steamAppId, scope),
      ];
      if (existing.isNotEmpty) {
        if (!mounted) return;
        setState(() => _state = _CreateState.idle);
        final proceed = await confirmDuplicate(
          context,
          existing: existing,
          proposed: entry,
        );
        if (!proceed || !mounted) return;
        setState(() => _state = _CreateState.creating);
      }
      final unsaved = await _createIn(scopes, createRequestFrom(entry));
      if (!mounted) return;
      setState(() => _state = _CreateState.created);
      _toast(
        unsaved.isEmpty
            ? 'Entry created successfully!'
            : 'Entry created, but ${unsaved.join(', ')} could not be saved',
      );
      _leave?.cancel();
      _leave = Timer(const Duration(milliseconds: 800), () {
        if (mounted) context.go(backTo);
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _state = _CreateState.failed);
      _toast(
        'Failed to create: '
        '${ApiException.from(error, 'Please try again.').message}',
      );
      _leave?.cancel();
      _leave = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _state = _CreateState.idle);
      });
    }
  }

  /// Creates the entry in each of [scopes] and adds the chosen categories of
  /// that backlog and the mods to it. A failure of the first entry is thrown;
  /// what fails after an entry exists is returned by name, so the user learns
  /// what to add by hand.
  Future<List<String>> _createIn(
    List<int?> scopes,
    wire.CreateBacklogEntryRequest request,
  ) async {
    final unsaved = <String>{};
    var createdAny = false;
    for (final scope in scopes) {
      final BacklogEntry created;
      try {
        created = await ref
            .read(entriesProvider(scope).notifier)
            .createEntry(request);
      } on Object {
        if (!createdAny) rethrow;
        unsaved.add(
          scope == null
              ? 'the entry in My Backlog'
              : 'the entry in the Shared Space',
        );
        continue;
      }
      createdAny = true;
      for (final categoryId in _categories[scope] ?? const <int>{}) {
        try {
          await ref
              .read(categoryActionsProvider(scope))
              .setAssigned(created.id, categoryId, assigned: true);
        } on Object {
          unsaved.add('some categories');
        }
      }
      for (final mod in _mods) {
        try {
          await ref
              .read(
                entryModActionsProvider((entryId: created.id, spaceId: scope)),
              )
              .add(mod.name, mod.url);
        } on Object {
          unsaved.add('some mods');
        }
      }
    }
    return unsaved.toList();
  }

  Future<void> _otherPlatform() async {
    final chosen = await showManagePlatformsSheet(
      context,
      initial: _platforms,
      inBacklog: [
        ..._prefill.platformOptions,
        ...ref.read(filterOptionsProvider).platforms,
      ],
    );
    if (chosen != null && mounted) setState(() => _platforms = chosen);
  }

  Future<void> _addMod() async {
    final mod = await showModSheet(context);
    if (mod != null && mounted) setState(() => _mods = [..._mods, mod]);
  }

  Future<void> _changeCover() async {
    final url = await showCoverPicker(
      context,
      initialQuery: _title.text.trim(),
      steamAppId: _resolvedAppId,
    );
    if (url != null && mounted) setState(() => _imageUrl.text = url);
  }

  void _searchAgain() {
    context.go(_backTo);
    ref.read(addGameRequestProvider.notifier).request();
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.text != value) controller.text = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    ref.watch(activeSpaceIdProvider);
    final lookup = _lookup;
    final lookingUp = _lookupApplies && lookup.isLoading;
    final steamHours = _steamHours;
    final waitingForPlaytime = steamHours.isLoading && !_playtimeTouched;
    if (_steamAppIdTyped == null) {
      _syncText(_steamAppId, _displayedSteamAppId);
    }
    if (!_playtimeTouched) _syncText(_playtime, _effectivePlaytime);
    final busy =
        _state == _CreateState.creating || _state == _CreateState.created;
    final canSubmit = !busy && !lookingUp && !waitingForPlaytime;
    final custom = _prefill.custom;

    final gutter = ShelfFormFactor.isCompact(context) ? 16.0 : 28.0;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.enter,
          meta: isMac,
          control: !isMac,
        ): () {
          if (canSubmit) unawaited(_submit());
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          key: const Key('page-creation'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(context, canSubmit, isMac, gutter),
            if (!custom && _prefill.hasMissingData)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
                child: _WarningBanner(message: _prefill.missingDataMessage),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 920;
                    final left = _leftColumn(tokens, style);
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(
    BuildContext context,
    bool canSubmit,
    bool isMac,
    double gutter,
  ) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final label = switch (_state) {
      _CreateState.creating => 'Creating...',
      _CreateState.created => 'Created!',
      _CreateState.failed => 'Failed',
      _CreateState.idle => 'Add Game',
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _prefill.custom ? 'New custom game' : 'New Game',
              style: style.page,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ShelfButton(
            key: const Key('creation-cancel'),
            label: 'Cancel',
            kind: ShelfButtonKind.quiet,
            onPressed: _state == _CreateState.creating
                ? null
                : () => context.go(_backTo),
          ),
          const SizedBox(width: 8),
          ShelfButton(
            key: const Key('creation-submit'),
            label: label,
            kind: _state == _CreateState.failed
                ? ShelfButtonKind.danger
                : ShelfButtonKind.primary,
            busy: _state == _CreateState.creating,
            onPressed: canSubmit ? () => unawaited(_submit()) : null,
          ),
          const SizedBox(width: 8),
          KeyHint(isMac ? '⌘↵' : 'Ctrl+↵'),
        ],
      ),
    );
  }

  Widget _leftColumn(ShelfTokens tokens, ShelfTextStyles style) {
    final serverUrl = ref.watch(serverUrlProvider).value;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _imageUrl,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfCover(
            title: _title.text.trim().isEmpty ? 'New Game' : _title.text.trim(),
            image: entryImage(serverUrl, value.text.trim()),
          ),
          const SizedBox(height: 10),
          ShelfButton(
            key: const Key('creation-search-again'),
            label: 'Search Again',
            onPressed: _state == _CreateState.creating ? null : _searchAgain,
          ),
          const SizedBox(height: 10),
          ShelfButton(
            key: const Key('creation-change-cover'),
            label: 'Change Cover',
            onPressed: _changeCover,
          ),
          if (_prefill.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('About', style: style.label),
            const SizedBox(height: 4),
            FoldableAbout(text: _prefill.description),
          ],
        ],
      ),
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
      height: ShelfHeight.input,
      child: TextField(
        key: key,
        controller: controller,
        enabled: enabled,
        onChanged: (value) {
          setState(() {});
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
      selected: [..._prefill.platformOptions, ..._platforms],
      inBacklog: ref.watch(filterOptionsProvider).platforms,
    );
    bool chosen(String name) =>
        _platforms.any((known) => known.toLowerCase() == name.toLowerCase());
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
              onSelected: () => setState(
                () => _platforms = togglePlatform(_platforms, option),
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
          text: _platforms.isEmpty ? 'Select platforms' : _platforms.join(', '),
          placeholder: _platforms.isEmpty,
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
          selected: _categories[scope] ?? const {},
          onSelectedChanged: (ids) => setState(() => _categories[scope] = ids),
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
                              setState(() => _targetTyped = target),
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
                _title,
                enabled: _prefill.custom,
              ),
            ),
            _row('Platform', _platformControl()),
            _row(
              'Genre',
              _field(
                const Key('creation-genre'),
                _genre,
                hint: 'Action, RPG, Adventure',
              ),
            ),
            _row(
              'Publisher',
              _field(
                const Key('creation-publisher'),
                _publisher,
                hint: 'The company that published the game',
              ),
            ),
            if (_prefill.custom)
              _row(
                'Image URL',
                _field(
                  const Key('creation-image-url'),
                  _imageUrl,
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
                  onChanged: (status) => setState(() => _status = status),
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
                  value: _interest,
                  onChanged: (value) => setState(() => _interest = value),
                ),
              ),
            ),
            _row(
              'Playtime (h)',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (steamHours.isLoading && !_playtimeTouched)
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
                    _playtime,
                    number: true,
                    width: 120,
                    onChanged: (_) => _playtimeTouched = true,
                  ),
                ],
              ),
            ),
            _row(
              'I own this game',
              ShelfSwitch(
                key: const Key('creation-owned'),
                value: _owned,
                label: 'I own this game',
                onChanged: (value) => setState(() => _owned = value),
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
              : _prefill.hasHltbData
              ? 'Times from HowLongToBeat - editable for custom games only.'
              : 'Editable because no match was found.',
          rows: [
            _row(
              'Main',
              _field(
                const Key('creation-main'),
                _mainStory,
                number: true,
                enabled: custom || !_prefill.hasHltbData,
                width: 120,
              ),
            ),
            _row(
              'Main + Extra',
              _field(
                const Key('creation-extra'),
                _mainStoryWithExtras,
                number: true,
                enabled: custom || !_prefill.hasHltbData,
                width: 120,
              ),
            ),
            _row(
              'Completionist',
              _field(
                const Key('creation-completionist'),
                _completionist,
                number: true,
                enabled: custom || !_prefill.hasHltbData,
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
                    _steamAppId,
                    number: true,
                    width: 160,
                    hint: custom
                        ? 'e.g. 504230'
                        : lookingUp
                        ? 'Looking up on Steam...'
                        : 'No Steam App ID found',
                    onChanged: (value) => _steamAppIdTyped = value,
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
                    value: _reviewStars,
                    onChanged: reviewable
                        ? (value) => setState(() => _reviewStars = value)
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
                  controller: _review,
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
                controller: _note,
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
            for (final (index, mod) in _mods.indexed)
              _row(
                mod.name,
                ShelfButton(
                  key: Key('creation-mod-remove-$index'),
                  label: 'Remove',
                  kind: ShelfButtonKind.quiet,
                  onPressed: () =>
                      setState(() => _mods = [..._mods]..removeAt(index)),
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
