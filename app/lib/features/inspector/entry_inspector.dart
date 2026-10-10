import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/backlog_scope.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/tabs.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/entry_changes.dart';
import 'package:backlog_manager/domain/format.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/domain/inspector_logic.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/safe_url.dart';
import 'package:backlog_manager/domain/split_list.dart';
import 'package:backlog_manager/domain/status_style.dart';
import 'package:backlog_manager/domain/trailer.dart';
import 'package:backlog_manager/features/achievements/achievement_progress.dart';
import 'package:backlog_manager/features/add_game/cover_picker_sheet.dart';
import 'package:backlog_manager/features/add_game/wrong_game_sheet.dart';
import 'package:backlog_manager/features/common/category_picker.dart';
import 'package:backlog_manager/features/common/status_select.dart';
import 'package:backlog_manager/features/inspector/entry_autosave.dart';
import 'package:backlog_manager/features/inspector/inspector_parts.dart';
import 'package:backlog_manager/features/library/library_actions.dart';
import 'package:backlog_manager/features/prices/price_sheet.dart';
import 'package:backlog_manager/features/space/share_to_space_button.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:backlog_manager/routing/current_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The inspector slot content for the game with [entryId]: it waits for the
/// entries, closes itself when the game is gone (deleted, or an unknown id in
/// the address) and otherwise shows the form of the game. The form is built
/// again for every game and every time the inspector opens, so it always
/// starts from the stored entry.
class EntryInspector extends ConsumerWidget {
  const EntryInspector({required this.entryId, super.key});

  final int entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider(ref.watch(backlogScopeProvider)));
    final list = entries.value;
    final entry = list?.where((e) => e.id == entryId).firstOrNull;

    if (list != null && entry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(ref.read(currentPathProvider));
      });
    }
    if (entry == null) {
      return _InspectorFrame(
        child: Center(
          child: Text(
            entries.hasError ? 'Could not load the game' : 'Loading...',
            key: const Key('inspector-loading'),
          ),
        ),
      );
    }
    return _InspectorForm(key: ValueKey(entryId), initial: entry);
  }
}

class _InspectorFrame extends StatelessWidget {
  const _InspectorFrame({required this.child, this.status});

  final Widget child;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Column(
      key: const Key('entry-inspector'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            child: Row(
              children: [
                Text(
                  'Details',
                  style: style.caption.copyWith(
                    color: tokens.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: status == null
                        ? null
                        : FittedBox(fit: BoxFit.scaleDown, child: status),
                  ),
                ),
                const SizedBox(width: 6),
                ShelfIconButton(
                  icon: Icons.close,
                  tooltip: 'Close inspector',
                  onPressed: () => context.go(
                    ProviderScope.containerOf(context)
                        .read(currentPathProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _InspectorForm extends ConsumerStatefulWidget {
  const _InspectorForm({required this.initial, super.key});

  final BacklogEntry initial;

  @override
  ConsumerState<_InspectorForm> createState() => _InspectorFormState();
}

class _InspectorFormState extends ConsumerState<_InspectorForm> {
  late EntryForm _form;
  late EntryForm _base;
  late BacklogEntry _stored;
  late final EntriesNotifier _entries;
  late final TextEditingController _playtime;
  late final TextEditingController _genre;
  late final TextEditingController _platform;
  late final TextEditingController _note;
  late final TextEditingController _review;
  late final EntryAutosave _autosave;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _stored = widget.initial;
    _form = entryFormFrom(_stored);
    _base = _form;
    _entries = ref.read(
      entriesProvider(ref.read(backlogScopeProvider)).notifier,
    );
    _playtime = TextEditingController(
      text: _form.playtime == null ? '' : formatHours(_form.playtime!),
    );
    _genre = TextEditingController(text: _form.genre);
    _platform = TextEditingController(text: _form.platform);
    _note = TextEditingController(text: _form.note);
    _review = TextEditingController(text: _form.review);
    _autosave = EntryAutosave(
      pending: () => diffEntryForm(_form, _stored),
      save: _save,
      onError: _onSaveError,
    );
    ref.listenManual(entriesProvider(ref.read(backlogScopeProvider)), (
      _,
      next,
    ) {
      final entry = next.value?.where((e) => e.id == _stored.id).firstOrNull;
      if (entry == null) return;
      _storedChanged(entry);
    });
  }

  @override
  void dispose() {
    _autosave
      ..flush()
      ..dispose();
    for (final controller in [_playtime, _genre, _platform, _note, _review]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(EntryFormChanges changes) {
    return _entries.updateEntry(
      _stored.id,
      EntryUpdate(
        status: changes.status,
        playtime: changes.playtime,
        interest: changes.interest,
        reviewStars: changes.reviewStars,
        review: changes.review,
        note: changes.note,
        owned: changes.owned,
        genre: changes.genre,
        platform: changes.platform,
        imageLink: changes.imageLink,
      ),
    );
  }

  void _onSaveError(Object error) {
    if (!mounted) return;
    showShelfToast(
      context,
      'Failed to save: ${ApiException.from(error, 'Please try again.').message}',
    );
  }

  /// The stored entry changed (a save finished, the game moved to another
  /// group): fields the user has not touched follow it.
  void _storedChanged(BacklogEntry entry) {
    final next = entryFormFrom(entry);
    setState(() {
      _stored = entry;
      _form = rebaseForm(form: _form, from: _base, to: next);
      _base = next;
      _syncText(_genre, _form.genre);
      _syncText(_platform, _form.platform);
      _syncText(_note, _form.note);
      _syncText(_review, _form.review);
      if (parsePlaytime(_playtime.text) != _form.playtime) {
        _syncText(
          _playtime,
          _form.playtime == null ? '' : formatHours(_form.playtime!),
        );
      }
    });
    _autosave.changed();
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text != value) controller.text = value;
  }

  void _edit(EntryForm Function(EntryForm form) change) {
    setState(() => _form = change(_form));
    _autosave.changed();
  }

  void _setPlaytime(String text) {
    final hours = parsePlaytime(text);
    _edit(
      (form) => hours == null
          ? form.copyWith(clearPlaytime: true)
          : form.copyWith(playtime: hours),
    );
  }

  Future<void> _updateImage() async {
    final url = await showShelfSheet<String>(
      context,
      builder: (_) => const _ImageUrlSheet(),
    );
    if (url != null) _edit((form) => form.copyWith(imageLink: url));
  }

  Future<void> _changeCover() async {
    final url = await showCoverPicker(
      context,
      initialQuery: _stored.title,
      steamAppId: _stored.steamAppId,
    );
    if (url == null || !mounted) return;
    _edit((form) => form.copyWith(imageLink: url));
    showShelfToast(context, 'Cover updated');
  }

  /// Makes the entry the game the user picked: title, cover, description,
  /// trailer and times come from the result and the Steam App ID goes.
  Future<void> _wrongGame() async {
    final result = await showWrongGameSheet(
      context,
      initialQuery: _stored.title,
    );
    if (result == null || !mounted) return;
    _autosave.flush();
    final update = EntryUpdate.wrongGame(wrongGameChanges(result));
    try {
      await _entries.updateEntry(_stored.id, update);
      if (mounted) showShelfToast(context, 'Game updated');
    } on Object catch (error) {
      if (!mounted) return;
      showShelfToast(
        context,
        'Failed to update game: '
        '${ApiException.from(error, 'Please try again.').message}',
      );
    }
  }

  void _watchTrailer() {
    final link = _stored.trailerLink;
    if (link == null || youtubeEmbedUrl(link) == null) return;
    ref.read(urlOpenerProvider)(Uri.parse(link));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final entry = _stored;
    final serverUrl = ref.watch(serverUrlProvider).value;
    final dirty = !diffEntryForm(_form, _stored).isEmpty;
    final genres = splitList(_form.genre);
    final platforms = splitList(_form.platform);
    final subtitle = [...genres, ...platforms].join(' · ');
    final completedOn = completedOnLabel(entry.completedAt);
    final dot = colorFromHex(statusColor(_form.status));
    final reviewable = canReview(_form.status);

    return _InspectorFrame(
      status: ValueListenableBuilder<SaveState>(
        valueListenable: _autosave.state,
        builder: (context, state, _) => SaveStatus(state: state, dirty: dirty),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 104,
                        child: ShelfCover(
                          title: entry.title,
                          image: entryImage(serverUrl, _form.imageLink),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              key: const Key('inspector-title'),
                              style: style.page.copyWith(fontSize: 22),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                key: const Key('inspector-subtitle'),
                                style: style.caption.copyWith(
                                  color: tokens.muted,
                                ),
                              ),
                            ],
                            if (completedOn != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                completedOn,
                                key: const Key('inspector-completed'),
                                style: style.caption.copyWith(
                                  color: tokens.muted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: dot,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const SizedBox(width: 9, height: 9),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: StatusSelect(
                                    spaceId: ref.watch(backlogScopeProvider),
                                    value: _form.status,
                                    onChanged: (status) => _edit(
                                      (form) => form.copyWith(status: status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CategoryPicker(
                    entryId: entry.id,
                    spaceId: ref.watch(backlogScopeProvider),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ShelfButton(
                        key: const Key('inspector-prices'),
                        label: 'Prices',
                        icon: Icons.sell_outlined,
                        onPressed: () => showPriceSheet(
                          context,
                          title: entry.title,
                          steamAppId: entry.steamAppId,
                        ),
                      ),
                      if (ref.watch(backlogScopeProvider) == null &&
                          ref.watch(activeSpaceIdProvider) != null)
                        ShareToSpaceButton(entry: entry),
                      ShelfButton(
                        key: const Key('inspector-update-image'),
                        label: 'Update image',
                        icon: Icons.edit_outlined,
                        onPressed: _updateImage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _stats(context, entry, tokens, style),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ShelfTabs(
                      labels: const [
                        'Overview',
                        'Progress',
                        'Review',
                        'Trailer',
                      ],
                      index: _tab,
                      onChanged: (index) => setState(() => _tab = index),
                    ),
                  ),
                  const SizedBox(height: 14),
                  switch (_tab) {
                    0 => _overview(entry, tokens, style),
                    1 => _progress(entry),
                    2 => _reviewTab(reviewable),
                    _ => _trailer(entry, tokens, style),
                  },
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.borderSubtle)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  ShelfButton(
                    key: const Key('inspector-delete'),
                    label: 'Delete',
                    kind: ShelfButtonKind.danger,
                    onPressed: () =>
                        LibraryActions(context, ref).deleteEntries([entry]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (ref.watch(backlogScopeProvider) == null)
                          ShelfButton(
                            key: const Key('inspector-wrong-game'),
                            label: 'Wrong game?',
                            onPressed: _wrongGame,
                          ),
                        ShelfButton(
                          key: const Key('inspector-change-cover'),
                          label: 'Change cover',
                          onPressed: _changeCover,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(
    BuildContext context,
    BacklogEntry entry,
    ShelfTokens tokens,
    ShelfTextStyles style,
  ) {
    final partner = entry.partnerPlaytime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatTile(
          icon: Icons.schedule,
          label: 'Playtime',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: ShelfHeight.input,
                      child: TextField(
                        key: const Key('inspector-playtime'),
                        controller: _playtime,
                        onChanged: _setPlaytime,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        style: style.fieldText,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: const InputDecoration(
                          hintText: 'Playtime in hours',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'hours',
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ],
              ),
              if (partner != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Your partner: ${formatHours(partner)}h',
                  key: const Key('inspector-partner'),
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        StatTile(
          icon: Icons.local_fire_department_outlined,
          label: 'Interest',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterestSegments(
                value: _form.interest,
                onChanged: (value) =>
                    _edit((form) => form.copyWith(interest: value)),
              ),
              const SizedBox(height: 6),
              Text(
                '${_form.interest} / ${InterestSegments.count}',
                key: const Key('inspector-interest'),
                style: style.caption.copyWith(color: tokens.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        StatTile(
          icon: Icons.check,
          label: 'Ownership',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _form.owned ? 'In my library' : 'Not owned',
                  key: const Key('inspector-owned-label'),
                  style: style.control,
                ),
              ),
              ShelfSwitch(
                value: _form.owned,
                label: 'Owned',
                onChanged: (value) =>
                    _edit((form) => form.copyWith(owned: value)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overview(
    BacklogEntry entry,
    ShelfTokens tokens,
    ShelfTextStyles style,
  ) {
    final description = entry.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfField(
          label: 'Genre (comma-separated)',
          hintText: 'RPG, Action, Adventure',
          controller: _genre,
          onChanged: (value) => _edit((form) => form.copyWith(genre: value)),
        ),
        const SizedBox(height: 12),
        ShelfField(
          label: 'Platform (comma-separated)',
          hintText: 'PC, PS5, Xbox',
          controller: _platform,
          onChanged: (value) => _edit((form) => form.copyWith(platform: value)),
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Description', style: style.label.copyWith(color: tokens.muted)),
          const SizedBox(height: 6),
          Text(
            description,
            key: const Key('inspector-description'),
            style: style.body.copyWith(color: tokens.text2, height: 1.55),
          ),
        ],
      ],
    );
  }

  Widget _progress(BacklogEntry entry) {
    final playtime = _form.playtime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'HowLongToBeat - your ${formatHours(playtime ?? 0)}h so far',
          key: const Key('inspector-hltb'),
          style: Theme.of(context).extension<ShelfTextStyles>()!.label,
        ),
        const SizedBox(height: 12),
        TimeBar(label: 'Main story', hours: entry.mainTime, playtime: playtime),
        const SizedBox(height: 12),
        TimeBar(
          label: 'Main + extra',
          hours: entry.mainPlusExtraTime,
          playtime: playtime,
        ),
        const SizedBox(height: 12),
        TimeBar(
          label: 'Completionist',
          hours: entry.completionTime,
          playtime: playtime,
        ),
        const SizedBox(height: 18),
        AchievementProgressSection(steamAppId: entry.steamAppId),
      ],
    );
  }

  Widget _reviewTab(bool reviewable) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfTextArea(
          label: 'Note',
          fieldKey: const Key('inspector-note'),
          controller: _note,
          hintText: 'Add any notes...',
          onChanged: (value) => _edit((form) => form.copyWith(note: value)),
        ),
        const SizedBox(height: 14),
        Text('Review', style: style.label.copyWith(color: tokens.muted)),
        const SizedBox(height: 6),
        Opacity(
          opacity: reviewable ? 1 : 0.5,
          child: StarRating(
            value: _form.reviewStars,
            onChanged: reviewable
                ? (value) => _edit((form) => form.copyWith(reviewStars: value))
                : null,
          ),
        ),
        const SizedBox(height: 8),
        ShelfTextArea(
          label: '',
          fieldKey: const Key('inspector-review'),
          controller: _review,
          enabled: reviewable,
          minLines: 3,
          hintText: reviewable
              ? 'Write your review here...'
              : 'Set the status to Completed to write a review',
          onChanged: (value) => _edit((form) => form.copyWith(review: value)),
        ),
      ],
    );
  }

  Widget _trailer(
    BacklogEntry entry,
    ShelfTokens tokens,
    ShelfTextStyles style,
  ) {
    if (youtubeEmbedUrl(entry.trailerLink) == null) {
      return Text(
        'No trailer available for this game.',
        key: const Key('inspector-no-trailer'),
        textAlign: TextAlign.center,
        style: style.caption.copyWith(color: tokens.muted),
      );
    }
    return TrailerCard(onPressed: _watchTrailer);
  }
}

class _ImageUrlSheet extends StatefulWidget {
  const _ImageUrlSheet();

  @override
  State<_ImageUrlSheet> createState() => _ImageUrlSheetState();
}

class _ImageUrlSheetState extends State<_ImageUrlSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final url = _controller.text.trim();
    if (!isHttpUrl(url)) {
      setState(() => _error = 'Enter the address of an image (http or https).');
      return;
    }
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    return ShelfSheet(
      title: 'Update image',
      width: ShelfSheetWidth.compact,
      footer: ShelfSheetFooter(
        onCancel: () => Navigator.of(context).pop(),
        primary: ShelfButton(
          key: const Key('image-apply'),
          label: 'Update image URL',
          kind: ShelfButtonKind.primary,
          onPressed: _apply,
        ),
      ),
      child: ShelfField(
        label: 'Image URL',
        hintText: 'Enter image URL',
        controller: _controller,
        autofocus: true,
        error: _error,
        onSubmitted: (_) => _apply(),
      ),
    );
  }
}
