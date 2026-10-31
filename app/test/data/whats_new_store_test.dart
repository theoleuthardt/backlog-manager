import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/data/whats_new.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'release_source_test.dart' show ReleaseAdapter;

class MemoryWhatsNewStore implements WhatsNewStore {
  MemoryWhatsNewStore([this.version]);

  String? version;

  @override
  Future<String?> read() async => version;

  @override
  Future<void> write(String version) async => this.version = version;
}

class FakeNotesSource implements ReleaseNotesSource {
  FakeNotesSource({this.notes = "## What's Changed\n* feat: a new thing\n"});

  String notes;
  bool fails = false;
  final asked = <String>[];

  @override
  Future<AppRelease?> release(String version) async {
    asked.add(version);
    if (fails) throw Exception('offline');
    return AppRelease(
      version: version,
      pageUrl: Uri.parse(
        'https://github.com/theoleuthardt/backlog-manager/releases/tag/v$version',
      ),
      notes: notes,
    );
  }
}

ProviderContainer containerFor({
  required String installed,
  required MemoryWhatsNewStore store,
  required FakeNotesSource source,
}) {
  final container = ProviderContainer(
    overrides: [
      installedVersionProvider.overrideWith((ref) async => installed),
      whatsNewStoreProvider.overrideWithValue(store),
      releaseNotesSourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('what is new', () {
    test('shows the changes after an update and remembers them', () async {
      final store = MemoryWhatsNewStore('0.9.17');
      final source = FakeNotesSource();
      final container = containerFor(
        installed: '0.9.18',
        store: store,
        source: source,
      );

      final news = await container.read(whatsNewProvider.future);
      expect(news?.version, '0.9.18');
      expect(news?.changes, ['A new thing']);
      expect(store.version, '0.9.17', reason: 'not seen before it shows');

      await container.read(whatsNewProvider.notifier).seen();
      expect(store.version, '0.9.18');
      expect(container.read(whatsNewProvider).value, isNull);
    });

    test('a first install only remembers its version', () async {
      final store = MemoryWhatsNewStore();
      final source = FakeNotesSource();
      final container = containerFor(
        installed: '0.9.18',
        store: store,
        source: source,
      );

      expect(await container.read(whatsNewProvider.future), isNull);
      expect(store.version, '0.9.18');
      expect(source.asked, isEmpty);
    });

    test('shows nothing again for a version that was shown', () async {
      final source = FakeNotesSource();
      final container = containerFor(
        installed: '0.9.18',
        store: MemoryWhatsNewStore('0.9.18'),
        source: source,
      );

      expect(await container.read(whatsNewProvider.future), isNull);
      expect(source.asked, isEmpty);
    });

    test(
      'asks again at the next start when GitHub cannot be reached',
      () async {
        final store = MemoryWhatsNewStore('0.9.17');
        final container = containerFor(
          installed: '0.9.18',
          store: store,
          source: FakeNotesSource()..fails = true,
        );

        expect(await container.read(whatsNewProvider.future), isNull);
        expect(store.version, '0.9.17');
      },
    );

    test('a release without changes counts as shown', () async {
      final store = MemoryWhatsNewStore('0.9.17');
      final container = containerFor(
        installed: '0.9.18',
        store: store,
        source: FakeNotesSource(notes: '## Installing\n- **macOS:** open'),
      );

      expect(await container.read(whatsNewProvider.future), isNull);
      expect(store.version, '0.9.18');
    });
  });

  group('the release of a version', () {
    test('is read from the tag of that version, pre-releases too', () async {
      final adapter = ReleaseAdapter(
        routes: {
          '/repos/theoleuthardt/backlog-manager/releases/tags/v0.9.18': {
            'tag_name': 'v0.9.18',
            'prerelease': true,
            'html_url': 'https://github.com/theoleuthardt/backlog-manager/releases/tag/v0.9.18',
            'body': "## What's Changed\n* feat: new\n",
          },
        },
      );
      final source = GithubReleaseNotesSource(
        Dio()..httpClientAdapter = adapter,
      );

      final release = await source.release('0.9.18');

      expect(release?.version, '0.9.18');
      expect(release?.notes, contains('feat: new'));
      expect(release?.pageUrl.path, endsWith('/v0.9.18'));
    });

    test('is null when the version has no release', () async {
      final source = GithubReleaseNotesSource(
        Dio()..httpClientAdapter = ReleaseAdapter(status: 404),
      );

      expect(await source.release('9.9.9'), isNull);
    });
  });

  group('the last seen version', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('is null until one is stored, then that one', () async {
      const store = PreferencesWhatsNewStore();

      expect(await store.read(), isNull);
      await store.write('0.9.18');
      expect(await store.read(), '0.9.18');
    });
  });
}
