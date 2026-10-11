import 'dart:io';

import 'package:backlog_manager/platform/update_installer.dart';
import 'package:flutter_test/flutter_test.dart';

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
