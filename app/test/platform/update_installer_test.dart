import 'dart:io';

import 'package:backlog_manager/platform/update_installer.dart';
import 'package:flutter_test/flutter_test.dart';

const _androidArm64 =
    '3.13.5 (stable) (Tue Oct 6 00:00:00 2026 +0000) on "android_arm64"';
const _androidX64 =
    '3.13.5 (stable) (Tue Oct 6 00:00:00 2026 +0000) on "android_x64"';

void main() {
  late Directory dir;
  final started = <(String, List<String>)>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('blm-install-');
    started.clear();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> record(String executable, List<String> arguments) async {
    started.add((executable, arguments));
  }

  group('AppImageInstaller', () {
    test('is offered for an AppImage in a folder that can be written', () {
      final appImage = File('${dir.path}/Backlog.AppImage')
        ..writeAsStringSync('old');

      final installer = AppImageInstaller(appImagePath: appImage.path);

      expect(installer.payloadKey, 'linux-x64-appimage');
      expect(installer.stagingDirectory.path, dir.path);
    });

    test('is not offered when the file is gone', () {
      final installer = AppImageInstaller(appImagePath: '${dir.path}/none');

      expect(installer.payloadKey, isNull);
    });

    test('moves the new file over the old one and starts it', () async {
      final appImage = File('${dir.path}/Backlog.AppImage')
        ..writeAsStringSync('old');
      final payload = File('${dir.path}/.update')..writeAsStringSync('new');
      final installer = AppImageInstaller(
        appImagePath: appImage.path,
        start: record,
      );

      await installer.apply(payload);

      expect(appImage.readAsStringSync(), 'new');
      expect(payload.existsSync(), isFalse);
      expect(started.single.$1, appImage.path);
      expect(
        appImage.statSync().mode & 0x40,
        isNonZero,
        reason: 'the owner can execute it',
      );
    });
  });

  group('stableAppImageName', () {
    test('drops the version from the name of a release file', () {
      expect(
        stableAppImageName('Backlog-Manager_0.9.9_linux_x64.AppImage'),
        'Backlog-Manager.AppImage',
      );
      expect(
        stableAppImageName('Backlog-Manager_0.9.10_linux_x64.AppImage'),
        'Backlog-Manager.AppImage',
      );
      expect(
        stableAppImageName('Backlog-Manager-1.0.0-x86_64.AppImage'),
        'Backlog-Manager.AppImage',
      );
    });

    test('keeps a name the user chose without a version', () {
      expect(
        stableAppImageName('Backlog-Manager.AppImage'),
        'Backlog-Manager.AppImage',
      );
      expect(stableAppImageName('Backlog.AppImage'), 'Backlog.AppImage');
      expect(stableAppImageName('blm'), 'blm');
    });
  });

  group('AppImageInstaller with a version in the file name', () {
    const versioned = 'Backlog-Manager_0.9.9_linux_x64.AppImage';

    test('installs under the name without a version and starts that', () async {
      File('${dir.path}/$versioned').writeAsStringSync('old');
      final payload = File('${dir.path}/.update')..writeAsStringSync('new');
      final installer = AppImageInstaller(
        appImagePath: '${dir.path}/$versioned',
        start: record,
      );

      await installer.apply(payload);

      final stable = File('${dir.path}/Backlog-Manager.AppImage');
      expect(stable.readAsStringSync(), 'new');
      expect(payload.existsSync(), isFalse);
      expect(started.single.$1, stable.path);
      expect(stable.statSync().mode & 0x40, isNonZero);
    });

    test('leaves a link at the old path so shortcuts keep working', () async {
      File('${dir.path}/$versioned').writeAsStringSync('old');
      final payload = File('${dir.path}/.update')..writeAsStringSync('new');
      final installer = AppImageInstaller(
        appImagePath: '${dir.path}/$versioned',
        start: record,
      );

      await installer.apply(payload);

      final old = Link('${dir.path}/$versioned');
      expect(old.existsSync(), isTrue);
      expect(old.targetSync(), 'Backlog-Manager.AppImage');
      expect(File(old.path).readAsStringSync(), 'new');
    });

    test('replaces an earlier file of the stable name', () async {
      File('${dir.path}/$versioned').writeAsStringSync('old');
      File('${dir.path}/Backlog-Manager.AppImage').writeAsStringSync('stale');
      final payload = File('${dir.path}/.update')..writeAsStringSync('new');
      final installer = AppImageInstaller(
        appImagePath: '${dir.path}/$versioned',
        start: record,
      );

      await installer.apply(payload);

      expect(
        File('${dir.path}/Backlog-Manager.AppImage').readAsStringSync(),
        'new',
      );
    });

    test(
      'a file that already has the stable name stays and gets no link',
      () async {
        final stable = File('${dir.path}/Backlog-Manager.AppImage')
          ..writeAsStringSync('old');
        final payload = File('${dir.path}/.update')..writeAsStringSync('new');
        final installer = AppImageInstaller(
          appImagePath: stable.path,
          start: record,
        );

        await installer.apply(payload);

        expect(stable.readAsStringSync(), 'new');
        expect(FileSystemEntity.isLinkSync(stable.path), isFalse);
        expect(
          dir.listSync().map((e) => e.path.split('/').last).toList()..sort(),
          ['Backlog-Manager.AppImage'],
        );
        expect(started.single.$1, stable.path);
      },
    );
  });

  group('systemUpdateInstaller', () {
    test('Linux outside an AppImage cannot update in place', () {
      expect(
        systemUpdateInstaller(operatingSystem: 'linux', environment: {}),
        isNull,
      );
    });

    test('Linux with APPIMAGE uses that file', () {
      final installer = systemUpdateInstaller(
        operatingSystem: 'linux',
        environment: {'APPIMAGE': '/opt/Backlog.AppImage'},
      );

      expect(installer, isA<AppImageInstaller>());
    });

    test('macOS finds the bundle of the executable', () {
      final installer = systemUpdateInstaller(
        operatingSystem: 'macos',
        environment: {},
        resolvedExecutable:
            '/Applications/Backlog Manager.app/Contents/MacOS/backlog_manager',
        processId: 42,
      );

      expect(installer, isA<MacDmgInstaller>());
      expect(
        (installer! as MacDmgInstaller).bundlePath,
        '/Applications/Backlog Manager.app',
      );
    });

    test('macOS outside a bundle (flutter run) cannot update', () {
      expect(
        systemUpdateInstaller(
          operatingSystem: 'macos',
          environment: {},
          resolvedExecutable: '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        ),
        isNull,
      );
    });

    test('Windows runs the setup', () {
      final installer = systemUpdateInstaller(
        operatingSystem: 'windows',
        environment: {},
        resolvedExecutable: r'C:\Apps\Backlog Manager\backlog_manager.exe',
      );

      expect(installer, isA<WindowsExeInstaller>());
    });

    test('Android hands the APK to the system installer', () {
      final installer = systemUpdateInstaller(
        operatingSystem: 'android',
        environment: {},
        platformVersion: _androidArm64,
      );

      expect(installer, isA<AndroidApkInstaller>());
      expect(installer!.payloadKey, 'android-arm64-apk');
      expect(installer.restartsApp, isFalse);
      expect(installer.allowsDowngrade, isFalse);
    });

    test('iOS cannot update itself', () {
      expect(
        systemUpdateInstaller(operatingSystem: 'ios', environment: {}),
        isNull,
      );
    });

    test('the desktop installers restart the app', () {
      final installer = systemUpdateInstaller(
        operatingSystem: 'windows',
        environment: {},
        resolvedExecutable: r'C:\Apps\backlog_manager.exe',
      );

      expect(installer!.restartsApp, isTrue);
      expect(installer.allowsDowngrade, isTrue);
    });
  });

  group('AndroidApkInstaller', () {
    final handedOver = <String>[];
    setUp(handedOver.clear);

    AndroidApkInstaller installerAnswering(
      String? answer, {
      String platformVersion = _androidArm64,
    }) => AndroidApkInstaller(
      platformVersion: platformVersion,
      handOver: (path) async {
        handedOver.add(path);
        return answer;
      },
    );

    test('is only offered on 64-bit ARM, the only APK of a release', () {
      expect(installerAnswering('started').payloadKey, 'android-arm64-apk');
      expect(
        installerAnswering('started', platformVersion: _androidX64).payloadKey,
        isNull,
      );
    });

    test('hands the downloaded APK to the system installer', () async {
      final payload = File('${dir.path}/.blm-update-1.2.3')
        ..writeAsStringSync('apk');

      await installerAnswering('started').apply(payload);

      expect(handedOver, [payload.path]);
    });

    test('says when Android needs the permission to install apps', () async {
      final payload = File('${dir.path}/.blm-update-1.2.3')
        ..writeAsStringSync('apk');

      await expectLater(
        installerAnswering('permission').apply(payload),
        throwsA(isA<InstallPermissionNeeded>()),
      );
    });

    test('fails on any other answer', () async {
      final payload = File('${dir.path}/.blm-update-1.2.3')
        ..writeAsStringSync('apk');

      await expectLater(
        installerAnswering(null).apply(payload),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('MacDmgInstaller', () {
    test(
      'hands the disk image, the bundle and the pid to the script',
      () async {
        final installer = MacDmgInstaller(
          bundlePath: '/Applications/Backlog Manager.app',
          processId: 77,
          start: record,
        );

        await installer.apply(File('/tmp/update.dmg'));

        final (executable, arguments) = started.single;
        expect(executable, '/bin/sh');
        expect(arguments.first, '-c');
        expect(arguments[1], macUpdateScript);
        expect(arguments.sublist(3), [
          '/tmp/update.dmg',
          '/Applications/Backlog Manager.app',
          '77',
        ]);
      },
    );

    test('the script waits for the app, replaces the bundle and opens it', () {
      expect(macUpdateScript, contains('kill -0 "\$3"'));
      expect(macUpdateScript, contains('hdiutil attach -nobrowse -readonly'));
      expect(macUpdateScript, contains('ditto'));
      expect(macUpdateScript, contains('open "\$2"'));
      expect(macUpdateScript, isNot(contains('/Applications')));
    });
  });

  group('WindowsExeInstaller', () {
    test(
      'writes a batch file that runs the setup and starts the app',
      () async {
        final installer = WindowsExeInstaller(
          executablePath: r'C:\Apps\Backlog Manager\backlog_manager.exe',
          start: record,
        );
        final payload = File('${dir.path}/update.exe')..writeAsStringSync('x');

        await installer.apply(payload);

        final (executable, arguments) = started.single;
        expect(executable, 'cmd.exe');
        expect(arguments, ['/c', '${payload.path}.cmd']);
        final script = File('${payload.path}.cmd').readAsStringSync();
        expect(script, contains('"${payload.path}" /VERYSILENT'));
        expect(script, contains('/NORESTART'));
        expect(
          script,
          contains(r'start "" "C:\Apps\Backlog Manager\backlog_manager.exe"'),
        );
        expect(script, contains(r'del "%~f0"'));
      },
    );
  });
}
