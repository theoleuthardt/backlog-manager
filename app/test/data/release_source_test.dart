import 'dart:convert';
import 'dart:typed_data';

import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class ReleaseAdapter implements HttpClientAdapter {
  ReleaseAdapter({
    this.status = 200,
    this.body = const {},
    this.routes = const {},
    this.octetStreamPaths = const {},
  });

  final int status;
  final Map<String, Object?> body;

  /// Answers by request path (and `status` for the rest).
  final Map<String, Object?> routes;

  /// Paths answered as `application/octet-stream`, which is how GitHub
  /// serves a release asset such as `app-update.json`.
  final Set<String> octetStreamPaths;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final routed = routes[options.uri.path];
    return ResponseBody.fromString(
      jsonEncode(routed ?? body),
      routed != null ? 200 : status,
      headers: {
        Headers.contentTypeHeader: [
          octetStreamPaths.contains(options.uri.path)
              ? 'application/octet-stream'
              : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GithubReleaseSource sourceFor(ReleaseAdapter adapter) => GithubReleaseSource(
  Dio()..httpClientAdapter = adapter,
  UpdateChannel.preview,
);

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
      adapter.requests.last.uri.path,
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

  group('a release with an in-place update manifest', () {
    const manifestPath =
        '/theoleuthardt/backlog-manager/releases/download/v1.2.0/app-update.json';
    final manifest = {
      'version': '1.2.0',
      'notes': 'Faster',
      'page_url': 'https://github.com/theoleuthardt/backlog-manager/releases/tag/v1.2.0',
      'payloads': {
        'linux-x64-appimage': {
          'url': 'https://github.com/theoleuthardt/backlog-manager/releases/download/v1.2.0/a.AppImage',
          'sha256': 'a' * 64,
          'size': 10,
          'signature': 'c2ln',
        },
      },
    };
    Map<String, Object?> release({
      String tag = 'v1.2.0',
      bool prerelease = true,
      bool draft = false,
      bool withAsset = true,
    }) => {
      'tag_name': tag,
      'prerelease': prerelease,
      'draft': draft,
      'assets': [
        if (withAsset)
          {
            'name': 'app-update.json',
            'browser_download_url': 'https://github.com$manifestPath',
          },
      ],
    };

    test('is read when GitHub serves the manifest as octet-stream', () async {
      final adapter = ReleaseAdapter(
        routes: {
          '/repos/theoleuthardt/backlog-manager/releases': [release()],
          manifestPath: manifest,
        },
        octetStreamPaths: {manifestPath},
      );

      final found = await sourceFor(adapter).latest();

      expect(found!.version, '1.2.0');
      expect(found.manifest!.payloads.keys, ['linux-x64-appimage']);
    });

    test('a manifest that is not JSON is skipped, not fatal', () async {
      final adapter = ReleaseAdapter(
        routes: {
          '/repos/theoleuthardt/backlog-manager/releases': [release()],
          manifestPath: 'not json',
          '/repos/theoleuthardt/backlog-manager/releases/latest': {
            'tag_name': 'v1.1.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://github.com/theoleuthardt/backlog-manager/releases/tag/v1.1.0',
          },
        },
        octetStreamPaths: {manifestPath},
      );

      final found = await sourceFor(adapter).latest();

      expect(found!.version, '1.1.0');
    });

    test('is found among the pre-releases and carries its payloads', () async {
      final adapter = ReleaseAdapter(
        routes: {
          '/repos/theoleuthardt/backlog-manager/releases': [release()],
          manifestPath: manifest,
        },
      );

      final found = await sourceFor(adapter).latest();

      expect(found!.version, '1.2.0');
      expect(found.notes, 'Faster');
      expect(found.manifest!.payloads.keys, ['linux-x64-appimage']);
    });

    test(
      'is skipped for a draft and for a release without the asset',
      () async {
        final adapter = ReleaseAdapter(
          routes: {
            '/repos/theoleuthardt/backlog-manager/releases': [
              release(draft: true),
              release(withAsset: false),
            ],
          },
          status: 404,
        );

        final found = await sourceFor(adapter).latest();

        expect(found, isNull);
      },
    );

    test(
      'falls back to the latest stable release without a manifest',
      () async {
        final adapter = ReleaseAdapter(
          routes: {
            '/repos/theoleuthardt/backlog-manager/releases': [
              release(withAsset: false),
            ],
            '/repos/theoleuthardt/backlog-manager/releases/latest': {
              'tag_name': 'v0.9.4',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://github.com/theoleuthardt/backlog-manager/releases/tag/v0.9.4',
            },
          },
        );

        final found = await sourceFor(adapter).latest();

        expect(found!.version, '0.9.4');
        expect(found.manifest, isNull);
      },
    );
  });

  group('the update channel', () {
    const base = '/theoleuthardt/backlog-manager/releases';
    const preview = '$base/download/v1.2.0/app-update.json';
    const stable = '$base/download/v1.1.0/app-update.json';

    Map<String, Object?> manifestOf(String version) => {
      'version': version,
      'notes': 'Notes $version',
      'page_url':
          'https://github.com/theoleuthardt/backlog-manager/releases/tag/v$version',
      'payloads': {
        'linux-x64-appimage': {
          'url':
              'https://github.com/theoleuthardt/backlog-manager/releases/download/v$version/a.AppImage',
          'sha256': 'a' * 64,
          'size': 10,
          'signature': 'c2ln',
        },
      },
    };

    Map<String, Object?> release(
      String tag,
      String manifestUrl, {
      required bool prerelease,
    }) => {
      'tag_name': tag,
      'prerelease': prerelease,
      'draft': false,
      'assets': [
        {
          'name': 'app-update.json',
          'browser_download_url': 'https://github.com$manifestUrl',
        },
      ],
    };

    ReleaseAdapter adapter() => ReleaseAdapter(
      routes: {
        '/repos$base': [
          release('v1.2.0', preview, prerelease: true),
          release('v1.1.0', stable, prerelease: false),
        ],
        preview: manifestOf('1.2.0'),
        stable: manifestOf('1.1.0'),
      },
    );

    GithubReleaseSource sourceOf(
      ReleaseAdapter adapter,
      UpdateChannel channel,
    ) => GithubReleaseSource(Dio()..httpClientAdapter = adapter, channel);

    test('preview takes the newest release, a pre-release too', () async {
      final found = await sourceOf(adapter(), UpdateChannel.preview).latest();

      expect(found!.version, '1.2.0');
    });

    test('stable skips pre-releases and takes the newest normal one', () async {
      final found = await sourceOf(adapter(), UpdateChannel.stable).latest();

      expect(found!.version, '1.1.0');
    });

    test('stable falls back to the latest release when only pre-releases carry a manifest', () async {
      final only = ReleaseAdapter(
        routes: {
          '/repos$base': [release('v1.2.0', preview, prerelease: true)],
          preview: manifestOf('1.2.0'),
          '/repos$base/latest': {
            'tag_name': 'v0.9.2',
            'draft': false,
            'prerelease': false,
            'html_url': 'https://github.com/theoleuthardt/backlog-manager/releases/tag/v0.9.2',
          },
        },
      );

      final found = await sourceOf(only, UpdateChannel.stable).latest();

      expect(found!.version, '0.9.2');
      expect(found.manifest, isNull);
    });

    test('the default channel is stable, like the setting', () {
      expect(GithubReleaseSource().channel, UpdateChannel.stable);
    });
  });
}
