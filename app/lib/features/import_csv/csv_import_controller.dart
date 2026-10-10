import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/csv_import_api.dart';
import 'package:backlog_manager/domain/csv_import.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the import is busy with.
enum CsvImportPhase { idle, readingHeaders, previewing, submitting }

/// A row the server did not import, with the reason.
class SkippedRow {
  const SkippedRow({required this.title, required this.reason});

  final String title;
  final String reason;
}

/// The state of the import: the file, the column mapping, the preview rows
/// and the progress of the running request.
class CsvImportState {
  const CsvImportState({
    this.fileName,
    this.content,
    this.headers,
    this.config = const CsvColumnConfig(),
    this.order,
    this.byIndex = const {},
    this.phase = CsvImportPhase.idle,
    this.processed,
    this.total,
    this.skipped = const [],
  });

  final String? fileName;
  final String? content;
  final Map<String, String>? headers;
  final CsvColumnConfig config;

  /// The row indexes in file order; null until a preview has been made.
  final List<int>? order;
  final Map<int, CsvPreviewRow> byIndex;
  final CsvImportPhase phase;
  final int? processed;
  final int? total;
  final List<SkippedRow> skipped;

  bool get busy => phase != CsvImportPhase.idle;
  bool get hasFile => headers != null;
  bool get hasPreview => order != null;

  List<CsvPreviewRow> get rows => [
    for (final index in order ?? const <int>[]) byIndex[index]!,
  ];

  CsvPreviewRow? rowAt(int rowIndex) => byIndex[rowIndex];

  CsvImportState copyWith({
    CsvColumnConfig? config,
    CsvImportPhase? phase,
    int? processed,
    int? total,
    bool clearProgress = false,
    List<int>? order,
    Map<int, CsvPreviewRow>? byIndex,
    bool clearPreview = false,
    List<SkippedRow>? skipped,
  }) {
    return CsvImportState(
      fileName: fileName,
      content: content,
      headers: headers,
      config: config ?? this.config,
      order: clearPreview ? null : order ?? this.order,
      byIndex: clearPreview ? const {} : byIndex ?? this.byIndex,
      phase: phase ?? this.phase,
      processed: clearProgress ? null : processed ?? this.processed,
      total: clearProgress ? null : total ?? this.total,
      skipped: skipped ?? this.skipped,
    );
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Runs the steps of the CSV import. Every step that can end in a message for
/// the user returns it, the page shows it as a toast.
class CsvImportController extends Notifier<CsvImportState> {
  StreamSubscription<SseEvent>? _subscription;
  Completer<Object?>? _pending;

  @override
  CsvImportState build() {
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
    });
    return const CsvImportState();
  }

  /// Reads the header of a chosen file and starts the column mapping with the
  /// default columns; the message is null on success.
  Future<String?> loadFile(String fileName, String content) async {
    state = CsvImportState(
      fileName: fileName,
      phase: CsvImportPhase.readingHeaders,
      skipped: state.skipped,
    );
    try {
      final headers = await ref.read(csvImportApiProvider).headers(content);
      if (!ref.mounted) return null;
      state = CsvImportState(
        fileName: fileName,
        content: content,
        headers: headers,
        skipped: state.skipped,
      );
      return null;
    } on Object catch (error) {
      if (!ref.mounted) return null;
      state = CsvImportState(skipped: state.skipped);
      return ApiException.from(error, 'Failed to read CSV headers').message;
    }
  }

  void setConfig(CsvColumnConfig config) {
    state = state.copyWith(config: config);
  }

  /// Leaves the file and the preview, for "Choose another file" and Cancel.
  void reset() {
    unawaited(_subscription?.cancel());
    state = const CsvImportState();
  }

  /// Stops the running preview or import.
  void cancel() {
    final pending = _pending;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const _Cancelled());
    }
  }

  Future<Object?> _consume(Stream<SseEvent> stream) {
    final pending = Completer<Object?>();
    _pending = pending;
    _subscription = stream.listen(
      (event) {
        switch (event) {
          case SseProgress(:final processed, :final total):
            if (ref.mounted) {
              state = state.copyWith(processed: processed, total: total);
            }
          case SseDone(:final data):
            if (!pending.isCompleted) pending.complete(data);
          case SseError(:final message):
            if (!pending.isCompleted) {
              pending.completeError(ApiException(message));
            }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!pending.isCompleted) pending.completeError(error, stackTrace);
      },
      onDone: () {
        if (!pending.isCompleted) {
          pending.completeError(const SseStreamEndedException());
        }
      },
    );
    return pending.future.whenComplete(() {
      _subscription = null;
      _pending = null;
    });
  }

  /// Matches the file against the game databases and shows the rows; the
  /// message is null when there is a preview to look at.
  Future<String?> preview() async {
    final content = state.content;
    if (content == null || state.busy) return null;
    state = state.copyWith(
      phase: CsvImportPhase.previewing,
      clearProgress: true,
    );
    try {
      final data = await _consume(
        ref.read(csvImportApiProvider).preview(content, state.config),
      );
      final rows = [
        for (final json in data! as List<dynamic>)
          CsvPreviewRow.fromJson(json as Map<String, dynamic>),
      ];
      if (!ref.mounted) return null;
      state = state.copyWith(
        phase: CsvImportPhase.idle,
        clearProgress: true,
        order: [for (final row in rows) row.rowIndex],
        byIndex: {for (final row in rows) row.rowIndex: row},
      );
      return rows.isEmpty ? 'No rows with a title found to preview' : null;
    } on _Cancelled {
      return _idle('Preview cancelled');
    } on Object catch (error) {
      return _idle(
        ApiException.from(error, 'Failed to preview CSV import').message,
      );
    }
  }

  String? _idle(String message) {
    if (ref.mounted) {
      state = state.copyWith(phase: CsvImportPhase.idle, clearProgress: true);
    }
    return message;
  }

  void updateRow(CsvPreviewRow row) {
    if (!state.byIndex.containsKey(row.rowIndex)) return;
    state = state.copyWith(byIndex: {...state.byIndex, row.rowIndex: row});
  }

  void removeRow(int rowIndex) {
    final order = state.order;
    if (order == null) return;
    state = state.copyWith(
      order: [
        for (final index in order)
          if (index != rowIndex) index,
      ],
      byIndex: {...state.byIndex}..remove(rowIndex),
    );
  }

  void chooseGame(int rowIndex, GameSearchResult result) {
    final row = state.byIndex[rowIndex];
    if (row != null) updateRow(applyWrongGame(row, result));
  }

  /// Creates the rows of the preview; the message is the result for the
  /// toast. A successful import ends the session and keeps the skipped rows.
  Future<String?> submit() async {
    final rows = state.rows;
    if (rows.isEmpty || state.busy) return null;
    state = state.copyWith(
      phase: CsvImportPhase.submitting,
      clearProgress: true,
    );
    try {
      final data = await _consume(ref.read(csvImportApiProvider).submit(rows));
      final result = data! as Map<String, dynamic>;
      final created = (result['created'] as List<dynamic>).length;
      final skipped = [
        for (final item in result['skipped'] as List<dynamic>)
          SkippedRow(
            title: (item as Map<String, dynamic>)['title'] as String,
            reason: item['reason'] as String,
          ),
      ];
      if (!ref.mounted) return null;
      ref.invalidate(entriesProvider(null));
      state = CsvImportState(skipped: skipped);
      return importResultMessage(created, skipped.length);
    } on _Cancelled {
      return _idle('Import cancelled');
    } on Object catch (error) {
      return _idle(
        ApiException.from(error, 'Failed to submit CSV import').message,
      );
    }
  }
}

final csvImportProvider =
    NotifierProvider.autoDispose<CsvImportController, CsvImportState>(
      CsvImportController.new,
    );

/// One row of the preview; only the row that changes notifies its widget.
final csvRowProvider = Provider.autoDispose.family<CsvPreviewRow?, int>(
  (ref, rowIndex) =>
      ref.watch(csvImportProvider.select((state) => state.rowAt(rowIndex))),
);
