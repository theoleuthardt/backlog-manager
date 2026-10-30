import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/entry_mod_providers.dart';
import 'package:backlog_manager/data/game_info_providers.dart';
import 'package:backlog_manager/domain/creation_form.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/inspector/mods_section.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _hours(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

/// What the creation tool knows about one game before it is created: the
/// prefill of the search and everything the user typed or chose. It outlives
/// its form, so a game of a batch keeps its values while it is folded. The
/// status and the target are null until the user chose them for this game;
/// until then the defaults of the page apply.
class CreationDraft extends ChangeNotifier {
  CreationDraft(this.prefill, {this.searchFailed = false})
    : title = TextEditingController(text: prefill.title),
      genre = TextEditingController(text: prefill.genres),
      publisher = TextEditingController(text: prefill.publisher),
      imageUrl = TextEditingController(text: prefill.imageUrl),
      playtime = TextEditingController(text: '0'),
      steamAppId = TextEditingController(),
      mainStory = TextEditingController(text: _hours(prefill.mainStory)),
      mainStoryWithExtras = TextEditingController(
        text: _hours(prefill.mainStoryWithExtras),
      ),
      completionist = TextEditingController(
        text: _hours(prefill.completionist),
      ),
      review = TextEditingController(),
      note = TextEditingController(),
      platforms = [
        if (prefill.defaultPlatform.isNotEmpty) prefill.defaultPlatform,
      ];

  final CreationPrefill prefill;

  /// Whether the search of a game of a batch failed, so [prefill] is a custom
  /// game only for now.
  final bool searchFailed;
  final TextEditingController title;
  final TextEditingController genre;
  final TextEditingController publisher;
  final TextEditingController imageUrl;
  final TextEditingController playtime;
  final TextEditingController steamAppId;
  final TextEditingController mainStory;
  final TextEditingController mainStoryWithExtras;
  final TextEditingController completionist;
  final TextEditingController review;
  final TextEditingController note;

  String? statusChosen;
  CreationTarget? targetChosen;
  int interest = 5;
  bool owned = false;
  int reviewStars = 0;
  bool playtimeTouched = false;
  String? steamAppIdTyped;
  List<String> platforms;
  final Map<int?, Set<int>> categories = {};
  List<ModInput> mods = const [];

  /// Tells the form and the page that a value changed.
  void changed() => notifyListeners();

  String status(String fallback) => statusChosen ?? fallback;

  CreationTarget target(CreationTarget fallback) => targetChosen ?? fallback;

  /// Whether the Steam App ID is looked up by the title: for a game the
  /// search found.
  bool get lookupApplies => !prefill.custom && prefill.title.isNotEmpty;

  /// The values of the form with the Steam App ID and the playtime of the
  /// Steam account looked up where the user did not type them, for a game
  /// whose form is not on the screen. A lookup that fails counts as none.
  Future<CreationInput> resolve(
    ProviderContainer container, {
    required String fallbackStatus,
  }) async {
    var appIdText = steamAppIdTyped;
    if (appIdText == null && lookupApplies) {
      try {
        appIdText = (await container.read(
          steamAppIdProvider(title.text.trim()).future,
        ))?.toString();
      } on Object {
        appIdText = null;
      }
    }
    final appId = resolvedSteamAppId(appIdText ?? '');
    double? fromSteam;
    if (appId != null && !playtimeTouched) {
      try {
        fromSteam = await container.read(steamPlaytimeProvider(appId).future);
      } on Object {
        fromSteam = null;
      }
    }
    return inputWith(
      fallbackStatus: fallbackStatus,
      steamAppIdText: appIdText ?? '',
      playtimeText: effectivePlaytime(
        touched: playtimeTouched,
        typed: playtime.text,
        fromSteam: fromSteam,
      ),
    );
  }

  /// The values of the form with the Steam App ID and playtime the form shows.
  CreationInput inputWith({
    required String fallbackStatus,
    required String steamAppIdText,
    required String playtimeText,
  }) => CreationInput(
    title: title.text,
    genre: genre.text,
    platform: platforms.join(', '),
    status: status(fallbackStatus),
    owned: owned,
    interest: interest,
    playtime: playtimeText,
    steamAppId: steamAppIdText,
    imageUrl: imageUrl.text,
    publisher: publisher.text,
    mainStory: mainStory.text,
    mainStoryWithExtras: mainStoryWithExtras.text,
    completionist: completionist.text,
    reviewStars: reviewStars,
    review: review.text,
    note: note.text,
  );

  @override
  void dispose() {
    for (final controller in [
      title,
      genre,
      publisher,
      imageUrl,
      playtime,
      steamAppId,
      mainStory,
      mainStoryWithExtras,
      completionist,
      review,
      note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Creates [request] in each of [scopes] and adds the chosen [categories] of
/// that backlog and the [mods] to it. A failure of the first entry is thrown;
/// what fails after an entry exists is returned by name, so the user learns
/// what to add by hand. It works on the provider container of the app, so
/// leaving the page while it runs does not stop it halfway. With the personal
/// backlog and the space it loads the personal one again at the end, so its
/// entry knows that the space has the game too (`in_shared_space`).
Future<List<String>> createEntryIn(
  ProviderContainer container, {
  required List<int?> scopes,
  required wire.CreateBacklogEntryRequest request,
  required Map<int?, Set<int>> categories,
  required List<ModInput> mods,
}) async {
  final unsaved = <String>{};
  var createdAny = false;
  for (final scope in scopes) {
    final BacklogEntry created;
    try {
      created = await container
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
    for (final categoryId in categories[scope] ?? const <int>{}) {
      try {
        await container
            .read(categoryActionsProvider(scope))
            .setAssigned(created.id, categoryId, assigned: true);
      } on Object {
        unsaved.add('some categories');
      }
    }
    for (final mod in mods) {
      try {
        await container
            .read(
              entryModActionsProvider((entryId: created.id, spaceId: scope)),
            )
            .add(mod.name, mod.url);
      } on Object {
        unsaved.add('some mods');
      }
    }
  }
  if (scopes.length > 1 && scopes.contains(null)) {
    try {
      await container.read(entriesProvider(null).notifier).refresh();
    } on Object {
      return unsaved.toList();
    }
  }
  return unsaved.toList();
}
