import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/sse_runner.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/steam_api.dart';
import 'package:backlog_manager/domain/steam_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the Steam page is busy with.
enum SteamPhase { idle, previewing, importing }

/// The Steam page: the source, the preview rows, which of them are checked
/// and the progress of the running request.
class SteamState {
  const SteamState({
    this.source = SteamSource.library,
    this.rows,
    this.selected = const {},
    this.phase = SteamPhase.idle,
    this.processed,
    this.total,
    this.query = '',
  });

  final SteamSource source;

  /// The preview of [source]; null until it was loaded.
  final List<SteamRow>? rows;
  final Set<int> selected;
  final SteamPhase phase;
  final int? processed;
  final int? total;
  final String query;

  bool get busy => phase != SteamPhase.idle;

  List<SteamRow> get visible => filterSteamRows(rows ?? const [], query);

  SteamState copyWith({
    SteamSource? source,
    List<SteamRow>? rows,
    bool clearRows = false,
    Set<int>? selected,
    SteamPhase? phase,
    int? processed,
    int? total,
    bool clearProgress = false,
    String? query,
  }) {
    return SteamState(
      source: source ?? this.source,
      rows: clearRows ? null : rows ?? this.rows,
      selected: selected ?? this.selected,
      phase: phase ?? this.phase,
      processed: clearProgress ? null : processed ?? this.processed,
      total: clearProgress ? null : total ?? this.total,
      query: query ?? this.query,
    );
  }
}

/// A message for the user and whether it is a warning.
class SteamNotice {
  const SteamNotice(this.message, {this.warning = false});

  final String message;
  final bool warning;
}

/// Runs the previews and imports of the Steam page. The steps that end in
/// something to tell the user return it, the page shows it as toasts.
class SteamController extends Notifier<SteamState> {
  final _runner = SseRunner();

  @override
  SteamState build() {
    ref.onDispose(_runner.cancel);
    return const SteamState();
  }

  void setSource(SteamSource source) {
    if (state.busy || source == state.source) return;
    state = SteamState(source: source, query: state.query);
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggle(int steamAppId) {
    final selected = {...state.selected};
    if (!selected.remove(steamAppId)) selected.add(steamAppId);
    state = state.copyWith(selected: selected);
  }

  void selectAll() {
    state = state.copyWith(
      selected: {
        ...state.selected,
        for (final row in state.visible) row.steamAppId,
      },
    );
  }

  void selectNone() {
    final visible = {for (final row in state.visible) row.steamAppId};
    state = state.copyWith(selected: state.selected.difference(visible));
  }

  /// Stops the running preview or import.
  void cancel() => _runner.cancel();

  /// Loads the preview of the source; the notice is set on failure.
  Future<SteamNotice?> load() async {
    if (state.busy) return null;
    final source = state.source;
    state = SteamState(
      source: source,
      phase: SteamPhase.previewing,
      query: state.query,
    );
    try {
      final List<SteamRow> rows;
      if (source == SteamSource.library) {
        final data = await _runner.run(
          ref.read(steamApiProvider).libraryPreview(),
          onProgress: (processed, total) {
            if (ref.mounted) {
              state = state.copyWith(processed: processed, total: total);
            }
          },
        );
        rows = [
          for (final json in data! as List<dynamic>)
            SteamRow.fromJson(json as Map<String, dynamic>),
        ];
      } else {
        rows = await ref.read(steamApiProvider).wishlistPreview();
      }
      if (!ref.mounted) return null;
      state = SteamState(
        source: source,
        rows: rows,
        selected: {for (final row in rows) row.steamAppId},
        query: state.query,
      );
      return null;
    } on SseCancelled {
      return _idle('Preview cancelled');
    } on Object catch (error) {
      return _idle(
        ApiException.from(
          error,
          source == SteamSource.library
              ? 'Failed to load Steam library preview'
              : 'Failed to load Steam wishlist',
        ).message,
      );
    }
  }

  SteamNotice _idle(String message) {
    if (ref.mounted) {
      state = state.copyWith(phase: SteamPhase.idle, clearProgress: true);
    }
    return SteamNotice(message);
  }

  /// Imports the checked rows. A cancelled or failed import keeps the
  /// preview and what was already created stays.
  Future<List<SteamNotice>> import() async {
    final rows = state.rows;
    if (rows == null || state.busy) return const [];
    final source = state.source;
    final ids = [
      for (final row in rows)
        if (state.selected.contains(row.steamAppId)) row.steamAppId,
    ];
    if (ids.isEmpty) return const [];
    state = state.copyWith(phase: SteamPhase.importing, clearProgress: true);
    try {
      final api = ref.read(steamApiProvider);
      final data = await _runner.run(
        source == SteamSource.library
            ? api.importLibrary(ids)
            : api.importWishlist(ids),
        onProgress: (processed, total) {
          if (ref.mounted) {
            state = state.copyWith(processed: processed, total: total);
          }
        },
      );
      final created = (data! as List<dynamic>).length;
      if (!ref.mounted) return const [];
      ref.invalidate(entriesProvider(null));
      state = SteamState(source: SteamSource.library, query: state.query);
      if (source == SteamSource.wishlist) {
        await ref.read(authControllerProvider.notifier).refreshUser();
      }
      final skipped = source == SteamSource.wishlist
          ? skippedWishlistMessage(ids.length, created)
          : null;
      return [
        SteamNotice(importedMessage(source, created)),
        if (skipped != null) SteamNotice(skipped, warning: true),
      ];
    } on SseCancelled {
      return [_idle('Import cancelled')];
    } on Object catch (error) {
      return [
        _idle(
          ApiException.from(
            error,
            source == SteamSource.library
                ? 'Failed to import Steam library'
                : 'Failed to import Steam wishlist',
          ).message,
        ),
      ];
    }
  }
}

final steamProvider = NotifierProvider.autoDispose<SteamController, SteamState>(
  SteamController.new,
);

/// The progress of the playtime sync of the library toolbar.
class PlaytimeSyncState {
  const PlaytimeSyncState({this.running = false, this.processed, this.total});

  final bool running;
  final int? processed;
  final int? total;

  double get fraction {
    final total = this.total;
    if (processed == null || total == null || total <= 0) return 0;
    return processed! / total;
  }
}

class PlaytimeSyncController extends Notifier<PlaytimeSyncState> {
  final _runner = SseRunner();

  @override
  PlaytimeSyncState build() {
    ref.onDispose(_runner.cancel);
    return const PlaytimeSyncState();
  }

  /// Syncs the playtimes; the result is the toast.
  Future<String?> run() async {
    if (state.running) return null;
    state = const PlaytimeSyncState(running: true);
    try {
      final data = await _runner.run(
        ref.read(steamApiProvider).syncPlaytimes(),
        onProgress: (processed, total) {
          if (ref.mounted) {
            state = PlaytimeSyncState(
              running: true,
              processed: processed,
              total: total,
            );
          }
        },
      );
      if (!ref.mounted) return null;
      ref.invalidate(entriesProvider(null));
      return playtimeSyncMessage((data! as List<dynamic>).length);
    } on Object catch (error) {
      return ApiException.from(error, 'Failed to sync Steam playtimes').message;
    } finally {
      if (ref.mounted) state = const PlaytimeSyncState();
    }
  }
}

final playtimeSyncProvider =
    NotifierProvider<PlaytimeSyncController, PlaytimeSyncState>(
      PlaytimeSyncController.new,
    );
