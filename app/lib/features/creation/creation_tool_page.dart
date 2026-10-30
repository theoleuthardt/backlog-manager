import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/creation_form.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/features/add_game/game_result_parts.dart';
import 'package:backlog_manager/features/add_game/wrong_game_sheet.dart';
import 'package:backlog_manager/features/common/status_select.dart';
import 'package:backlog_manager/features/creation/creation_draft.dart';
import 'package:backlog_manager/features/creation/creation_game_form.dart';
import 'package:backlog_manager/features/creation/duplicate_sheet.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _CreateState { idle, creating, created, failed }

/// How many searches of a batch run at the same time.
const _batchSearches = 4;

/// Below this width a game of a batch puts its buttons under its title.
const _batchActionsBreak = 520.0;

/// The form for new games. With one game ([CreationPrefill.fromQuery]) it is
/// filled from a search result or empty for a custom game. With `batch` in
/// the address (one title per line, [batchCreationLocation]) every title is
/// looked up and takes the best search result (a title the search does not
/// know becomes a custom game), and the games are listed as folding entries,
/// each with the same form; "Add to" and the status at the top are the
/// defaults of all games, which a game can change for itself. Everything the
/// inspector sets on a game can be set here too: several platforms (also ones
/// of its own), the publisher, categories and mods, and with an active Shared
/// Space whether the game goes to the personal backlog, the space or both. It
/// checks for duplicates in each of them before it creates the entries, then
/// adds the categories and mods to each, and returns to the library
/// afterwards.
class CreationToolPage extends ConsumerStatefulWidget {
  const CreationToolPage({required this.query, super.key});

  /// The query of the address, see [CreationPrefill.fromQuery].
  final Map<String, String> query;

  @override
  ConsumerState<CreationToolPage> createState() => _CreationToolPageState();
}

class _CreationToolPageState extends ConsumerState<CreationToolPage> {
  late final CreationPrefill _prefill;
  late final List<String>? _batch = widget.query.containsKey('batch')
      ? batchTitles(widget.query['batch']!)
      : null;
  CreationDraft? _single;
  List<CreationDraft>? _drafts;
  final _open = <CreationDraft>{};
  var _searched = 0;
  String _defaultStatus = '';
  CreationTarget? _defaultTargetChosen;
  _CreateState _state = _CreateState.idle;
  Timer? _leave;

  bool get _isBatch => _batch != null;

  @override
  void initState() {
    super.initState();
    _prefill = CreationPrefill.fromQuery(widget.query);
    final batch = _batch;
    if (batch == null) {
      _single = CreationDraft(_prefill)..addListener(_draftChanged);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_lookUp(batch));
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(shellStatusProvider.notifier)
            .update(
              counts: _isBatch
                  ? 'New entries · not saved yet'
                  : 'New entry · not saved yet',
            );
      }
    });
  }

  /// Rebuilds the page with the form of one game, so the submit button
  /// follows the lookups of what was typed.
  void _draftChanged() => setState(() {});

  @override
  void dispose() {
    _leave?.cancel();
    _single?.dispose();
    for (final draft in _drafts ?? const <CreationDraft>[]) {
      draft.dispose();
    }
    super.dispose();
  }

  /// Searches every title of the batch, [_batchSearches] at a time, and makes
  /// a draft of its best result, or a custom game when the search finds
  /// nothing or fails (marked, so "Wrong Game?" can search it again). It
  /// stops searching once the page is gone.
  Future<void> _lookUp(List<String> titles) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final drafts = List<CreationDraft?>.filled(titles.length, null);
    var next = 0;
    Future<void> worker() async {
      while (mounted && next < titles.length) {
        final index = next++;
        final title = titles[index];
        List<GameSearchResult> results;
        var failed = false;
        try {
          results = await container.read(
            gameSearchProvider((term: title, deep: false)).future,
          );
        } on Object {
          results = const [];
          failed = true;
        }
        if (!mounted) return;
        final best = results.firstOrNull;
        drafts[index] = CreationDraft(
          best == null
              ? CreationPrefill(custom: true, title: title)
              : CreationPrefill.fromResult(best),
          searchFailed: failed,
        );
        if (mounted) setState(() => _searched++);
      }
    }

    await Future.wait([for (var i = 0; i < _batchSearches; i++) worker()]);
    if (!mounted) {
      for (final draft in drafts) {
        draft?.dispose();
      }
      return;
    }
    setState(() => _drafts = [for (final draft in drafts) draft!]);
  }

  int? get _activeSpaceId => ref.read(activeSpaceIdProvider);

  CreationTarget get _defaultTarget {
    if (_activeSpaceId == null) return CreationTarget.personal;
    return _defaultTargetChosen ??
        (_prefill.targetsSpace
            ? CreationTarget.space
            : CreationTarget.personal);
  }

  CreationTarget _targetOf(CreationDraft draft) => _activeSpaceId == null
      ? CreationTarget.personal
      : draft.target(_defaultTarget);

  String get _backTo {
    final target = _isBatch ? _defaultTarget : _targetOf(_single!);
    return target == CreationTarget.space ? AppRoutes.space : AppRoutes.library;
  }

  void _toast(String message) {
    if (mounted) showShelfToast(context, message);
  }

  void _finished(String message) {
    setState(() => _state = _CreateState.created);
    _toast(message);
    final backTo = _backTo;
    _leave?.cancel();
    _leave = Timer(const Duration(milliseconds: 800), () {
      if (mounted) context.go(backTo);
    });
  }

  void _failed(String message) {
    setState(() => _state = _CreateState.failed);
    _toast(message);
    _leave?.cancel();
    _leave = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _state = _CreateState.idle);
    });
  }

  /// Checks the duplicates of [draft] in each of its backlogs, asks when
  /// there are some, and creates it: true with what could not be saved after
  /// the entry existed, false when the user did not want it or the page is
  /// gone. A failure is thrown. One game frees the page while it asks, so a
  /// declined duplicate leaves the form to change; a batch stays busy until
  /// every game had its turn.
  Future<(bool, List<String>)> _create(
    CreationDraft draft,
    CreationInput input,
    CreationTarget target,
  ) async {
    final container = ProviderScope.containerOf(context, listen: false);
    var entry = buildNewEntry(input, draft.prefill);
    final scopes = target.scopes(_activeSpaceId);
    final existing = [
      for (final scope in scopes)
        ...await container
            .read(backlogApiProvider)
            .duplicates(entry.title, entry.steamAppId, scope),
    ];
    if (existing.isNotEmpty) {
      if (!mounted) return (false, const <String>[]);
      if (!_isBatch) setState(() => _state = _CreateState.idle);
      final choice = await confirmDuplicate(
        context,
        existing: existing,
        proposed: entry,
      );
      if (choice == DuplicateChoice.skip || !mounted) {
        return (false, const <String>[]);
      }
      if (choice == DuplicateChoice.addWithoutSteamAppId) {
        entry = entry.withoutSteamAppId();
      }
      if (!_isBatch) setState(() => _state = _CreateState.creating);
    }
    if (!mounted) return (false, const <String>[]);
    final unsaved = await createEntryIn(
      container,
      scopes: scopes,
      request: createRequestFrom(entry),
      categories: {
        for (final scope in scopes) scope: {...?draft.categories[scope]},
      },
      mods: [...draft.mods],
    );
    return (true, unsaved);
  }

  Future<void> _submit() async {
    if (_state == _CreateState.creating || _state == _CreateState.created) {
      return;
    }
    if (_isBatch) return _submitBatch();
    final draft = _single!;
    _leave?.cancel();
    setState(() => _state = _CreateState.creating);
    final input = await draft.resolve(
      ProviderScope.containerOf(context, listen: false),
      fallbackStatus: '',
    );
    if (!mounted) return;
    final problem = validateCreation(input);
    if (problem != null) {
      setState(() => _state = _CreateState.idle);
      _toast(problem);
      return;
    }
    try {
      final (created, unsaved) = await _create(draft, input, _targetOf(draft));
      if (!created || !mounted) return;
      _finished(
        unsaved.isEmpty
            ? 'Entry created successfully!'
            : 'Entry created, but ${unsaved.join(', ')} could not be saved',
      );
    } on Object catch (error) {
      if (!mounted) return;
      _failed(
        'Failed to create: '
        '${ApiException.from(error, 'Please try again.').message}',
      );
    }
  }

  /// Checks every game of the batch first (the first one that is not
  /// complete is opened and named, before any Steam lookup runs), then
  /// creates them one after the other
  /// with the defaults as they were when it started; the list is locked
  /// meanwhile.
  /// The games that were created leave the list; the others stay, with what
  /// went wrong in the toast.
  Future<void> _submitBatch() async {
    final drafts = _drafts;
    if (drafts == null || drafts.isEmpty) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final defaultStatus = _defaultStatus;
    final targets = {for (final draft in drafts) draft: _targetOf(draft)};
    _leave?.cancel();
    setState(() => _state = _CreateState.creating);
    for (final draft in drafts) {
      final problem = validateCreation(
        draft.inputWith(
          fallbackStatus: defaultStatus,
          steamAppIdText: '',
          playtimeText: '0',
        ),
      );
      if (problem != null) {
        setState(() {
          _state = _CreateState.idle;
          _open.add(draft);
        });
        final title = draft.title.text.trim();
        _toast(title.isEmpty ? problem : '$title: $problem');
        return;
      }
    }
    final inputs = <CreationDraft, CreationInput>{};
    var next = 0;
    Future<void> worker() async {
      while (mounted && next < drafts.length) {
        final draft = drafts[next++];
        inputs[draft] = await draft.resolve(
          container,
          fallbackStatus: defaultStatus,
        );
      }
    }

    await Future.wait([for (var i = 0; i < _batchSearches; i++) worker()]);
    if (!mounted) return;
    final done = <CreationDraft>[];
    final failures = <String>[];
    final unsaved = <String>{};
    for (final draft in drafts) {
      try {
        final (created, missing) = await _create(
          draft,
          inputs[draft]!,
          targets[draft]!,
        );
        if (!mounted) return;
        if (created) {
          done.add(draft);
          unsaved.addAll(missing);
        }
      } on Object catch (error) {
        if (!mounted) return;
        failures.add(
          '${draft.title.text.trim()} '
          '(${ApiException.from(error, 'failed').message})',
        );
      }
    }
    setState(() {
      for (final draft in done) {
        drafts.remove(draft);
        _open.remove(draft);
      }
    });
    done.forEach(_disposeLater);
    final count = done.length == 1 ? '1 game' : '${done.length} games';
    final created = unsaved.isEmpty
        ? '$count created'
        : '$count created, but ${unsaved.join(', ')} could not be saved';
    if (drafts.isEmpty) {
      _finished(created);
      return;
    }
    if (failures.isEmpty) {
      setState(() => _state = _CreateState.idle);
      if (done.isNotEmpty) _toast(created);
      return;
    }
    _failed(
      '${done.isEmpty ? '' : '$created. '}'
      'Not created: ${failures.join(', ')}',
    );
  }

  void _searchAgain() {
    context.go(_backTo);
    ref.read(addGameRequestProvider.notifier).request();
  }

  Future<void> _wrongGame(CreationDraft draft) async {
    final result = await showWrongGameSheet(
      context,
      initialQuery: draft.title.text.trim(),
    );
    final drafts = _drafts;
    if (result == null || !mounted || drafts == null) return;
    final index = drafts.indexOf(draft);
    if (index == -1) return;
    final replacement = CreationDraft(CreationPrefill.fromResult(result));
    setState(() {
      drafts[index] = replacement;
      if (_open.remove(draft)) _open.add(replacement);
    });
    _disposeLater(draft);
  }

  void _remove(CreationDraft draft) {
    setState(() {
      _drafts?.remove(draft);
      _open.remove(draft);
    });
    _disposeLater(draft);
  }

  /// Disposes a draft that left the list once the frame that removes its
  /// form is drawn, so the form never sees its controllers go away.
  void _disposeLater(CreationDraft draft) {
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    ref.watch(activeSpaceIdProvider);
    final single = _single;
    final busy =
        _state == _CreateState.creating || _state == _CreateState.created;
    final bool canSubmit;
    if (single != null) {
      final lookups = draftLookups(ref, single);
      final lookingUp = single.lookupApplies && lookups.lookup.isLoading;
      final waitingForPlaytime =
          lookups.steamHours.isLoading && !single.playtimeTouched;
      canSubmit = !busy && !lookingUp && !waitingForPlaytime;
    } else {
      canSubmit = !busy && (_drafts?.isNotEmpty ?? false);
    }

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
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 28),
                child: single != null
                    ? CreationGameForm(
                        draft: single,
                        fallbackStatus: '',
                        fallbackTarget: _defaultTarget,
                        busy: _state == _CreateState.creating,
                        onSearchAgain: _searchAgain,
                      )
                    : _batchList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batchList(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final drafts = _drafts;
    final total = _batch!.length;
    if (drafts == null) {
      return Column(
        key: const Key('batch-searching'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Looking up $_searched of $total games...',
            style: style.control.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 10),
          ShelfProgressBar(value: total == 0 ? 0 : _searched / total),
        ],
      );
    }
    final spaceId = _defaultTarget == CreationTarget.space
        ? _activeSpaceId
        : null;
    final busy =
        _state == _CreateState.creating || _state == _CreateState.created;
    return IgnorePointer(
      ignoring: busy,
      child: ExcludeFocus(
        excluding: busy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShelfFormGroup(
              title: 'For all games',
              description:
                  'Each game can change these for itself in its own form.',
              rows: [
                if (_activeSpaceId != null)
                  ShelfFormRow(
                    label: 'Add to',
                    control: SizedBox(
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
                              checked: _defaultTarget == target,
                              onSelected: () =>
                                  setState(() => _defaultTargetChosen = target),
                            ),
                        ],
                        builder: (context, controller) => ShelfSelectTrigger(
                          key: const Key('batch-target'),
                          text: switch (_defaultTarget) {
                            CreationTarget.personal => 'My Backlog',
                            CreationTarget.space => 'Shared Space',
                            CreationTarget.both => 'Both',
                          },
                          semanticLabel: 'Add to',
                          onPressed: () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                        ),
                      ),
                    ),
                  ),
                ShelfFormRow(
                  label: 'Status',
                  control: SizedBox(
                    width: 220,
                    child: KeyedSubtree(
                      key: const Key('batch-status'),
                      child: StatusSelect(
                        spaceId: spaceId,
                        value: _defaultStatus,
                        onChanged: (status) =>
                            setState(() => _defaultStatus = status),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (drafts.isEmpty)
              Text(
                'No games left in this list.',
                key: const Key('batch-empty'),
                style: style.control.copyWith(color: tokens.muted),
              ),
            for (final (index, draft) in drafts.indexed) ...[
              _BatchItem(
                key: ValueKey(draft),
                index: index,
                draft: draft,
                open: _open.contains(draft),
                busy: _state == _CreateState.creating,
                onToggle: () => setState(
                  () => _open.contains(draft)
                      ? _open.remove(draft)
                      : _open.add(draft),
                ),
                onWrongGame: () => unawaited(_wrongGame(draft)),
                onRemove: () => _remove(draft),
                form: CreationGameForm(
                  draft: draft,
                  fallbackStatus: _defaultStatus,
                  fallbackTarget: _defaultTarget,
                  busy: _state == _CreateState.creating,
                ),
              ),
              const SizedBox(height: 10),
            ],
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
    final count = _drafts?.length ?? _batch?.length ?? 1;
    final label = switch (_state) {
      _CreateState.creating => 'Creating...',
      _CreateState.created => 'Created!',
      _CreateState.failed => 'Failed',
      _CreateState.idle when _isBatch =>
        count == 1 ? 'Add 1 Game' : 'Add $count Games',
      _CreateState.idle => 'Add Game',
    };
    final title = _isBatch
        ? 'New Games'
        : _prefill.custom
        ? 'New custom game'
        : 'New Game';
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
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
}

/// One game of a batch: a header with its title and what the search found,
/// which folds [form] in and out, "Wrong Game?" and a button that takes it
/// off the list.
class _BatchItem extends StatelessWidget {
  const _BatchItem({
    required this.index,
    required this.draft,
    required this.open,
    required this.busy,
    required this.onToggle,
    required this.onWrongGame,
    required this.onRemove,
    required this.form,
    super.key,
  });

  final int index;
  final CreationDraft draft;
  final bool open;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onWrongGame;
  final VoidCallback onRemove;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final prefill = draft.prefill;
    final summary = draft.searchFailed
        ? 'The search failed - a custom game for now'
        : prefill.custom
        ? 'No match found - a custom game'
        : [
            if (prefill.platformOptions.isNotEmpty)
              prefill.platformOptions.join(', '),
            if (prefill.genres.isNotEmpty) prefill.genres,
          ].join(' · ');
    return DecoratedBox(
      key: Key('batch-item-$index'),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(ShelfRadius.panel),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final header = ShelfPressable(
                key: Key('batch-toggle-$index'),
                semanticLabel: open ? 'Fold in' : 'Fold out',
                onPressed: onToggle,
                builder: (context, state) => Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: tokens.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: draft.title,
                          builder: (context, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draft.title.text.trim().isEmpty
                                    ? 'Untitled game'
                                    : draft.title.text.trim(),
                                style: style.control.copyWith(
                                  color: tokens.foreground,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (summary.isNotEmpty)
                                Text(
                                  summary,
                                  style: style.caption.copyWith(
                                    color: prefill.custom
                                        ? tokens.accent
                                        : tokens.muted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShelfButton(
                    key: Key('batch-wrong-$index'),
                    label: 'Wrong Game?',
                    kind: ShelfButtonKind.quiet,
                    onPressed: busy ? null : onWrongGame,
                  ),
                  const SizedBox(width: 4),
                  ShelfButton(
                    key: Key('batch-remove-$index'),
                    label: 'Remove',
                    kind: ShelfButtonKind.quiet,
                    onPressed: busy ? null : onRemove,
                  ),
                  const SizedBox(width: 10),
                ],
              );
              if (constraints.maxWidth < _batchActionsBreak) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: actions,
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: header),
                  actions,
                ],
              );
            },
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: form,
            ),
        ],
      ),
    );
  }
}
