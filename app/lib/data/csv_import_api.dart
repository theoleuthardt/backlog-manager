import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/domain/csv_import.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The CSV import of the signed-in user.
abstract interface class CsvImportApi {
  /// The header of every column of the file by its letter.
  Future<Map<String, String>> headers(String content);

  /// Matches every row of the file against the game databases and the
  /// backlog without writing anything: progress messages, then `done` with
  /// the rows or `error`. Cancelling the subscription stops it on the server.
  Stream<SseEvent> preview(String content, CsvColumnConfig config);

  /// Creates the confirmed rows: progress messages, then `done` with the
  /// created and the skipped rows or `error`.
  Stream<SseEvent> submit(List<CsvPreviewRow> rows);
}

class ApiCsvImportApi implements CsvImportApi {
  const ApiCsvImportApi(this._dio);

  final Future<Dio> Function() _dio;

  @override
  Future<Map<String, String>> headers(String content) async {
    final dio = await _dio();
    final response = await wire.RestClient(dio).fallback
        .apiCsvHeadersGetCsvHeaders(
          body: wire.CsvHeadersRequest(content: content),
        );
    return response.headers;
  }

  @override
  Stream<SseEvent> preview(String content, CsvColumnConfig config) async* {
    final request = wire.MatchCsvRequest(
      content: content,
      titleColumn: config.titleColumn,
      genreColumn: config.genreColumn,
      platformColumn: config.platformColumn,
      statusColumn: config.statusColumn,
      playtimeColumn: config.playtimeColumn,
      ratingColumn: config.ratingColumn,
      completedAtColumn: config.completedAtColumn,
      noteColumns: config.noteColumns,
      reviewColumns: config.reviewColumns,
    );
    yield* openSse(
      await _dio(),
      '/api/csv/preview/stream',
      data: request.toJson(),
    );
  }

  @override
  Stream<SseEvent> submit(List<CsvPreviewRow> rows) async* {
    yield* openSse(
      await _dio(),
      '/api/csv/submit/stream',
      data: [for (final row in rows) row.toSubmitJson()],
    );
  }
}

final csvImportApiProvider = Provider<CsvImportApi>(
  (ref) => ApiCsvImportApi(() => ref.read(apiDioProvider.future)),
);
