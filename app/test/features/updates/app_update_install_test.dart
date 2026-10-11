import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/data/update_download.dart';
import 'package:backlog_manager/data/update_verifier.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:backlog_manager/domain/update_manifest.dart';
import 'package:backlog_manager/features/updates/app_update_state.dart';
import 'package:backlog_manager/platform/update_installer.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'linux-x64-appimage';
final _content = List<int>.generate(2000, (i) => i % 251);

class FixedSource implements ReleaseSource {
  FixedSource(this.release);

  final AppRelease release;

  @override
  Future<AppRelease?> latest() async => release;
}

class FakeDownloader implements UpdateDownloader {
  FakeDownloader(this.bytes, {this.fail = false});

  List<int> bytes;
  bool fail;
  final urls = <Uri>[];

  @override
  Future<void> download(
    Uri url,
    File target, {
    required void Function(int received, int total) onProgress,
  }) async {
    urls.add(url);
    if (fail) {
      target.writeAsBytesSync(bytes.sublist(0, 10));
      throw Exception('offline');
    }
    target.writeAsBytesSync(bytes);
    onProgress(bytes.length ~/ 2, bytes.length);
    onProgress(bytes.length, bytes.length);
  }
}

class FakeInstaller implements UpdateInstaller {
  FakeInstaller(this.stagingDirectory, {this.key = _key, this.fail = false});

  @override
  final Directory stagingDirectory;
  final String? key;
  final bool fail;
  final applied = <File>[];

  @override
  String? get payloadKey => key;

  @override
  Future<void> apply(File payload) async {
    if (fail) throw const FileSystemException('read-only');
    applied.add(payload);
  }
}

/// A release of [version] whose AppImage payload is [content], signed with a
/// new key, and the verifier that knows the key.
Future<({UpdateVerifier verifier, AppRelease release})> signedRelease({
  String version = '0.9.4',
  List<int>? content,
}) async {
  final bytes = content ?? _content;
  final keyPair = await Ed25519().newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final hash = await Sha256().hash(bytes);
  final sha256 = [
    for (final b in hash.bytes) b.toRadixString(16).padLeft(2, '0'),
  ].join();
  final signature = await Ed25519().sign(
    utf8.encode(updateMessage(version: version, key: _key, sha256: sha256)),
    keyPair: keyPair,
  );
  final page = Uri.parse('https://github.com/o/r/releases/tag/v$version');
  return (
    verifier: UpdateVerifier(Uint8List.fromList(publicKey.bytes)),
    release: AppRelease(
      version: version,
      pageUrl: page,
      manifest: UpdateManifest(
        version: version,
        pageUrl: page,
        payloads: {
          _key: UpdatePayload(
            url: Uri.parse('https://github.com/o/r/a.AppImage'),
            sha256: sha256,
            signature: base64Encode(signature.bytes),
            size: bytes.length,
          ),
        },
      ),
    ),
  );
}

void main() {
  late Directory dir;
  late UpdateVerifier verifier;
  late AppRelease release;
  var exited = 0;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('blm-install-state-');
    exited = 0;
    final signed = await signedRelease();
    verifier = signed.verifier;
    release = signed.release;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer containerFor({
    required UpdateDownloader downloader,
    UpdateInstaller? installer,
    UpdateVerifier? verifierOverride,
    bool noVerifier = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        releaseSourceProvider.overrideWithValue(FixedSource(release)),
        installedVersionProvider.overrideWith((ref) async => '0.9.3'),
        updateDownloaderProvider.overrideWithValue(downloader),
        updateInstallerProvider.overrideWithValue(
          installer ?? FakeInstaller(dir),
        ),
        updateVerifierProvider.overrideWithValue(
          noVerifier ? null : verifierOverride ?? verifier,
        ),
        appExitProvider.overrideWithValue(() => exited++),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ProviderContainer> checked(ProviderContainer container) async {
    await container.read(appUpdateProvider.notifier).check();
    return container;
  }

  File staged(String version) => File('${dir.path}/.blm-update-$version');

  test('downloads, verifies and leaves the update ready', () async {
    final downloader = FakeDownloader(_content);
    final container = await checked(containerFor(downloader: downloader));
    final notifier = container.read(appUpdateProvider.notifier);

    expect(notifier.canInstallInPlace, isTrue);
    await notifier.install();

    final state = container.read(appUpdateProvider);
    expect(state.install, UpdateInstall.ready);
    expect(state.staged!.path, staged('0.9.4').path);
    expect(state.staged!.readAsBytesSync(), _content);
    expect(downloader.urls.single.path, '/o/r/a.AppImage');
  });

  test('a payload that was changed is refused and removed', () async {
    final tampered = [..._content]..[100] ^= 0xff;
    final container = await checked(
      containerFor(downloader: FakeDownloader(tampered)),
    );

    await container.read(appUpdateProvider.notifier).install();

    final state = container.read(appUpdateProvider);
    expect(state.install, UpdateInstall.failed);
    expect(state.installError, contains('could not be verified'));
    expect(staged('0.9.4').existsSync(), isFalse);
    expect(state.staged, isNull);
  });

  test('a failed download keeps the version and removes the part', () async {
    final container = await checked(
      containerFor(downloader: FakeDownloader(_content, fail: true)),
    );

    await container.read(appUpdateProvider.notifier).install();

    final state = container.read(appUpdateProvider);
    expect(state.install, UpdateInstall.failed);
    expect(state.installError, contains('download failed'));
    expect(staged('0.9.4').existsSync(), isFalse);
    expect(state.release!.version, '0.9.4');
  });

  test('an install that cannot update in place is notify-only', () async {
    final container = await checked(
      containerFor(
        downloader: FakeDownloader(_content),
        installer: FakeInstaller(dir, key: null),
      ),
    );
    final notifier = container.read(appUpdateProvider.notifier);

    expect(notifier.canInstallInPlace, isFalse);
    await notifier.install();

    expect(container.read(appUpdateProvider).install, UpdateInstall.none);
  });

  test('without a key in the app nothing is installed', () async {
    final downloader = FakeDownloader(_content);
    final container = await checked(
      containerFor(downloader: downloader, noVerifier: true),
    );
    final notifier = container.read(appUpdateProvider.notifier);

    expect(notifier.canInstallInPlace, isFalse);
    await notifier.install();

    expect(downloader.urls, isEmpty);
  });

  test('restart applies the verified update and ends the app', () async {
    final installer = FakeInstaller(dir);
    final container = await checked(
      containerFor(downloader: FakeDownloader(_content), installer: installer),
    );
    final notifier = container.read(appUpdateProvider.notifier);
    await notifier.install();

    await notifier.restart();

    expect(installer.applied.single.path, staged('0.9.4').path);
    expect(exited, 1);
  });

  test('restart does nothing before the update is ready', () async {
    final installer = FakeInstaller(dir);
    final container = await checked(
      containerFor(downloader: FakeDownloader(_content), installer: installer),
    );

    await container.read(appUpdateProvider.notifier).restart();

    expect(installer.applied, isEmpty);
    expect(exited, 0);
  });

  test('a read-only install fails and keeps running', () async {
    final installer = FakeInstaller(dir, fail: true);
    final container = await checked(
      containerFor(downloader: FakeDownloader(_content), installer: installer),
    );
    final notifier = container.read(appUpdateProvider.notifier);
    await notifier.install();

    await notifier.restart();

    final state = container.read(appUpdateProvider);
    expect(state.install, UpdateInstall.failed);
    expect(state.installError, contains('could not be installed'));
    expect(exited, 0);
    expect(staged('0.9.4').existsSync(), isFalse);
  });

  test('a check that throws does not leave the install stuck', () async {
    final container = await checked(
      containerFor(
        downloader: FakeDownloader(_content),
        verifierOverride: _ThrowingVerifier(),
      ),
    );
    final notifier = container.read(appUpdateProvider.notifier);

    await notifier.install();

    final state = container.read(appUpdateProvider);
    expect(state.install, UpdateInstall.failed);
    expect(staged('0.9.4').existsSync(), isFalse);
    expect(notifier.canInstallInPlace, isTrue);
  });
}

class _ThrowingVerifier extends UpdateVerifier {
  _ThrowingVerifier() : super(Uint8List(32));

  @override
  Future<UpdateVerdict> verify({
    required File file,
    required UpdatePayload payload,
    required String version,
    required String key,
  }) async => throw const FileSystemException('removed');
}
