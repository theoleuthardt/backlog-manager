import 'dart:convert';
import 'dart:typed_data';

import 'package:backlog_manager/data/release_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class ReleaseAdapter implements HttpClientAdapter {
  ReleaseAdapter({this.status = 200, this.body = const {}});

  final int status;
  final Map<String, Object?> body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GithubReleaseSource sourceFor(ReleaseAdapter adapter) =>
    GithubReleaseSource(Dio()..httpClientAdapter = adapter);

void main() {
  test('asks GitHub for the latest release of the repository', () async {
    final adapter = ReleaseAdapter(
      body: {
        'tag_name': 'v0.9.4',
        'draft': false,
        'prerelease': false,
        'body': 'Fixes',
        'html_url': 'https://github.com/theoleuthardt/backlog-manager/releases/tag/v0.9.4',
      },
    );

    final release = await sourceFor(adapter).latest();

    expect(
      adapter.requests.single.uri.path,
      '/repos/theoleuthardt/backlog-manager/releases/latest',
    );
    expect(release!.version, '0.9.4');
    expect(release.notes, 'Fixes');
  });

  test('a repository without a release is no failure', () async {
    final release = await sourceFor(ReleaseAdapter(status: 404)).latest();

    expect(release, isNull);
  });

  test('other HTTP errors surface, such as a rate limit', () async {
    await expectLater(
      sourceFor(ReleaseAdapter(status: 403)).latest(),
      throwsA(isA<DioException>()),
    );
  });
}
