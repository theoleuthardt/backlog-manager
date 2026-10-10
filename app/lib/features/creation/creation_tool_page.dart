import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/creation_form.dart';
import 'package:backlog_manager/domain/inspector_logic.dart';
import 'package:backlog_manager/features/achievements/achievement_progress.dart';
import 'package:backlog_manager/features/add_game/cover_picker_sheet.dart';
import 'package:backlog_manager/features/add_game/game_result_parts.dart';
import 'package:backlog_manager/features/common/status_select.dart';
import 'package:backlog_manager/features/creation/duplicate_sheet.dart';
import 'package:backlog_manager/features/inspector/inspector_parts.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _CreateState { idle, creating, created, failed }

/// The form for a new game: filled from a search result or empty for a custom
/// game. It checks for duplicates before it creates the entry and returns to
/// the library afterwards.
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
  late final TextEditingController _platform;
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
  bool? _toSpaceTyped;
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
    _platform = TextEditingController(
      text: _prefill.platformOptions.firstOrNull ?? '',
    );
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
      _platform,
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

  bool get _toSpace =>
      _activeSpaceId != null && (_toSpaceTyped ?? _prefill.targetsSpace);

  int? get _targetSpaceId => _toSpace ? _activeSpaceId : null;

  String get _backTo => _toSpace ? AppRoutes.space : AppRoutes.library;

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
    platform: _platform.text,
    status: _status,
    owned: _owned,
    interest: _interest,
    playtime: _effectivePlaytime,
    steamAppId: _displayedSteamAppId,
    imageUrl: _imageUrl.text,
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
    final problem = validateCreation(input, toSpace: _toSpace);
    if (problem != null) {
      _toast(problem);
      return;
    }
    final entry = buildNewEntry(input, _prefill);
    final spaceId = _targetSpaceId;
    final backTo = _backTo;
    setState(() => _state = _CreateState.creating);
    try {
      final existing = await ref
          .read(backlogApiProvider)
          .duplicates(entry.title, entry.steamAppId, spaceId);
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
      await ref
          .read(entriesProvider(spaceId).notifier)
          .createEntry(createRequestFrom(entry));
      if (!mounted) return;
      setState(() => _state = _CreateState.created);
      _toast('Entry created successfully!');
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
            _toolbar(context, canSubmit, isMac),
            if (!custom && _prefill.hasMissingData)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                child: _WarningBanner(message: _prefill.missingDataMessage),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
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

  Widget _toolbar(BuildContext context, bool canSubmit, bool isMac) {
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final label = switch (_state) {
      _CreateState.creating => 'Creating...',
      _CreateState.created => 'Created!',
      _CreateState.failed => 'Failed',
      _CreateState.idle => 'Add game',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _prefill.custom ? 'New custom game' : 'New game',
              style: style.page,
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
            title: _title.text.trim().isEmpty ? 'New game' : _title.text.trim(),
            image: entryImage(serverUrl, value.text.trim()),
          ),
          const SizedBox(height: 10),
          ShelfButton(
            key: const Key('creation-search-again'),
            label: 'Search again',
            onPressed: _state == _CreateState.creating ? null : _searchAgain,
          ),
          const SizedBox(height: 10),
          ShelfButton(
            key: const Key('creation-change-cover'),
            label: 'Change cover',
            onPressed: _changeCover,
          ),
          if (_prefill.publisher.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                text: 'Published by ',
                style: style.caption.copyWith(color: tokens.muted),
                children: [
                  TextSpan(
                    text: _prefill.publisher,
                    style: style.caption.copyWith(
                      color: tokens.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              key: const Key('creation-publisher'),
            ),
          ],
          if (_prefill.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('About', style: style.label),
            const SizedBox(height: 4),
            Text(
              _prefill.description,
              key: const Key('creation-about'),
              style: style.caption.copyWith(color: tokens.text2, height: 1.5),
            ),
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
    final options = _prefill.platformOptions;
    if (options.isEmpty) {
      return _field(
        const Key('creation-platform'),
        _platform,
        hint: 'PC, PlayStation, Xbox',
      );
    }
    return SizedBox(
      width: 220,
      child: ShelfMenuAnchor(
        entries: [
          for (final option in options)
            ShelfMenuItem(
              label: option,
              checked: option == _platform.text,
              onSelected: () => setState(() => _platform.text = option),
            ),
        ],
        builder: (context, controller) => ShelfSelectTrigger(
          key: const Key('creation-platform'),
          text: _platform.text.isEmpty ? 'Select a platform' : _platform.text,
          placeholder: _platform.text.isEmpty,
          semanticLabel: 'Platform',
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }

  Widget _middleColumn(bool lookingUp) {
    final steamHours = _steamHours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfFormGroup(
          title: 'Game info',
          rows: [
            if (_activeSpaceId != null)
              _row(
                'Add to',
                SizedBox(
                  width: 220,
                  child: ShelfMenuAnchor(
                    entries: [
                      ShelfMenuItem(
                        label: 'My backlog',
                        checked: !_toSpace,
                        onSelected: () => setState(() => _toSpaceTyped = false),
                      ),
                      ShelfMenuItem(
                        label: 'Shared space',
                        checked: _toSpace,
                        onSelected: () => setState(() => _toSpaceTyped = true),
                      ),
                    ],
                    builder: (context, controller) => ShelfSelectTrigger(
                      key: const Key('creation-target'),
                      text: _toSpace ? 'Shared space' : 'My backlog',
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
          title: 'Your take',
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
            _row(
              'Interest',
              SizedBox(
                width: 220,
                child: Row(
                  children: [
                    Expanded(
                      child: InterestSegments(
                        value: _interest,
                        onChanged: (value) => setState(() => _interest = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_interest',
                      key: const Key('creation-interest'),
                      style: Theme.of(context)
                          .extension<ShelfTextStyles>()!
                          .control,
                    ),
                  ],
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
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
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
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final lookingUp = _lookupApplies && _lookup.isLoading;
    final reviewable = canReview(_status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfFormGroup(
          title: 'HowLongToBeat times',
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
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
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
              'Review stars',
              Opacity(
                opacity: reviewable ? 1 : 0.5,
                child: StarRating(
                  value: _reviewStars,
                  onChanged: reviewable
                      ? (value) => setState(() => _reviewStars = value)
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
        if (!reviewable)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Stars and review need the status Completed.',
              style: style.caption.copyWith(color: tokens.faint),
            ),
          ),
      ],
    );
  }
}

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
