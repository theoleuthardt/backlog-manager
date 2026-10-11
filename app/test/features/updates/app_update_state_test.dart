import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:backlog_manager/features/updates/app_update_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements ReleaseSource {
  FakeSource({this.release, this.fail = false});

  AppRelease? release;
  bool fail;
  int calls = 0;

  @override
  Future<AppRelease?> latest() async {
    calls++;
    if (fail) throw Exception('offline');
    return release;
  }
}

AppRelease releaseOf(String version) => AppRelease(
  version: version,
  pageUrl: Uri.parse(
    'https://github.com/theoleuthardt/backlog-manager/releases/tag/v$version',
  ),
);

void main() {
  late FakeSource source;
  late ProviderContainer container;

  ProviderContainer containerFor(
    FakeSource source, {
    String installed = '0.9.3',
  }) {
    final container = ProviderContainer(
      overrides: [
        releaseSourceProvider.overrideWithValue(source),
        installedVersionProvider.overrideWith((ref) async => installed),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    source = FakeSource(release: releaseOf('0.9.4'));
    container = containerFor(source);
  });

  AppUpdateState state() => container.read(appUpdateProvider);

  test('a newer release is available', () async {
    await container.read(appUpdateProvider.notifier).check();

    expect(state().check, UpdateCheck.available);
    expect(state().release!.version, '0.9.4');
  });

  test('the same version is up to date', () async {
    source.release = releaseOf('0.9.3');

    await container.read(appUpdateProvider.notifier).check();

    expect(state().check, UpdateCheck.upToDate);
    expect(state().release, isNull);
  });

  test('no release at all is up to date', () async {
    source.release = null;

    await container.read(appUpdateProvider.notifier).check();

    expect(state().check, UpdateCheck.upToDate);
  });

  test('a manual check reports a failure', () async {
    source.fail = true;

    await container.read(appUpdateProvider.notifier).check();

    expect(state().check, UpdateCheck.failed);
  });

  test('a quiet check leaves the state alone on a failure', () async {
    source.fail = true;

    await container.read(appUpdateProvider.notifier).check(quiet: true);

    expect(state().check, UpdateCheck.idle);
  });

  test('a check that is running is not started again', () async {
    final notifier = container.read(appUpdateProvider.notifier);

    await Future.wait([notifier.check(), notifier.check()]);

    expect(source.calls, 1);
  });

  test('the notification is remembered for the session', () async {
    final notifier = container.read(appUpdateProvider.notifier);
    await notifier.check();

    notifier.markAnnounced();
    await notifier.check();

    expect(state().announced, isTrue);
    expect(state().check, UpdateCheck.available);
  });
}
