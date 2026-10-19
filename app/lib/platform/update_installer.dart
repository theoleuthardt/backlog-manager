import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts a program that outlives the app.
typedef DetachedStarter = Future<void> Function(
  String executable,
  List<String> arguments,
);

Future<void> _startDetached(String executable, List<String> arguments) async {
  await Process.start(executable, arguments, mode: ProcessStartMode.detached);
}

/// Puts a downloaded installer in place of the running app and starts the
/// new version. The caller exits the app after [apply] returned.
abstract interface class UpdateInstaller {
  /// The key of the payload this install can apply (`{os}-{arch}-{format}`),
  /// or null when it cannot update in place: a DEB or RPM install, an app in
  /// a folder the user cannot write to.
  String? get payloadKey;

  /// A folder on the disk of the app, where a download is kept until it is
  /// applied.
  Directory get stagingDirectory;

  Future<void> apply(File payload);
}

bool _writable(Directory directory) {
  try {
    final probe = File('${directory.path}/.blm-write-test-$pid')
      ..writeAsStringSync('');
    probe.deleteSync();
    return true;
  } on FileSystemException {
    return false;
  }
}

final _versionInName = RegExp(r'[_-]v?\d+\.\d+\.\d+');

/// The file name an updated AppImage gets: a release file such as
/// `Backlog-Manager_0.9.9_linux_x64.AppImage` becomes
/// `Backlog-Manager.AppImage`, so the name (and a desktop entry that starts
/// it) does not carry a version that is out of date after the next update. A
/// name without a version is the user's own choice and is kept.
String stableAppImageName(String fileName) =>
    _versionInName.hasMatch(fileName) ? 'Backlog-Manager.AppImage' : fileName;

/// An AppImage replaces itself: the new file is moved to the stable name next
/// to the old one (the old one keeps running from its open inode) and
/// started. When the old file had a version in its name, its path becomes a
/// link to the new file (made under a temporary name and renamed over the old
/// path, so the path never goes missing), so desktop entries and shortcuts that point at it
/// keep working.
class AppImageInstaller implements UpdateInstaller {
  AppImageInstaller({required this.appImagePath, this._start = _startDetached});

  final String appImagePath;
  final DetachedStarter _start;

  @override
  String? get payloadKey =>
      File(appImagePath).existsSync() && _writable(stagingDirectory)
      ? 'linux-x64-appimage'
      : null;

  @override
  Directory get stagingDirectory => File(appImagePath).parent;

  @override
  Future<void> apply(File payload) async {
    final chmod = await Process.run('chmod', ['+x', payload.path]);
    if (chmod.exitCode != 0) {
      throw const FileSystemException('The update could not be made runnable');
    }
    final directory = stagingDirectory.path;
    final oldName = appImagePath.substring(appImagePath.lastIndexOf('/') + 1);
    final stableName = stableAppImageName(oldName);
    final target = '$directory/$stableName';
    await payload.rename(target);
    if (stableName != oldName) {
      final link = Link('$appImagePath.blm-link-$pid');
      await link.create(stableName);
      await link.rename(appImagePath);
    }
    await _start(target, const []);
  }
}

/// The shell script that replaces an app bundle with the one on a disk image
/// and opens it, once the running app (`$3`, a pid) is gone. It takes the
/// image (`$1`) and the bundle to replace (`$2`) as arguments, so no path is
/// ever part of the script text.
const macUpdateScript = r'''
set -e
while kill -0 "$3" 2>/dev/null; do sleep 0.3; done
mount_point=$(mktemp -d)
hdiutil attach -nobrowse -readonly -mountpoint "$mount_point" "$1" >/dev/null
trap 'hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true' EXIT
new_app=$(ls -d "$mount_point"/*.app | head -n 1)
staged="$2.update"
rm -rf "$staged"
ditto "$new_app" "$staged"
rm -rf "$2"
mv "$staged" "$2"
rm -f "$1"
open "$2"
''';

/// A macOS app replaces its own bundle from the disk image.
class MacDmgInstaller implements UpdateInstaller {
  MacDmgInstaller({
    required this.bundlePath,
    required this.processId,
    this._start = _startDetached,
  });

  final String bundlePath;
  final int processId;
  final DetachedStarter _start;

  @override
  String? get payloadKey =>
      bundlePath.endsWith('.app') && _writable(Directory(bundlePath).parent)
      ? 'macos-universal-dmg'
      : null;

  @override
  Directory get stagingDirectory => Directory.systemTemp;

  @override
  Future<void> apply(File payload) => _start('/bin/sh', [
    '-c',
    macUpdateScript,
    'blm-update',
    payload.path,
    bundlePath,
    '$processId',
  ]);
}

/// The batch file that, once the running app has had a moment to close, runs
/// the installer without a window, starts the new version and removes itself.
/// It is a file because `cmd.exe` does not read quotes the way Dart escapes
/// them in an argument.
String windowsUpdateScript({
  required String installer,
  required String executable,
}) =>
    '@echo off\r\n'
    'ping -n 3 127.0.0.1 >nul\r\n'
    '"$installer" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART\r\n'
    'start "" "$executable"\r\n'
    'del "%~f0"\r\n';

/// A Windows install runs the setup of the new version over itself.
class WindowsExeInstaller implements UpdateInstaller {
  WindowsExeInstaller({
    required this.executablePath,
    this._start = _startDetached,
  });

  final String executablePath;
  final DetachedStarter _start;

  @override
  String? get payloadKey => 'windows-x64-exe';

  @override
  Directory get stagingDirectory => Directory.systemTemp;

  @override
  Future<void> apply(File payload) async {
    final script = File('${payload.path}.cmd')
      ..writeAsStringSync(
        windowsUpdateScript(
          installer: payload.path,
          executable: executablePath,
        ),
      );
    await _start('cmd.exe', ['/c', script.path]);
  }
}

/// The installer of the system the app runs on, or null where it cannot
/// update itself (Linux outside an AppImage).
UpdateInstaller? systemUpdateInstaller({
  String? operatingSystem,
  Map<String, String>? environment,
  String? resolvedExecutable,
  int? processId,
}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  final env = environment ?? Platform.environment;
  final executable = resolvedExecutable ?? Platform.resolvedExecutable;
  switch (os) {
    case 'linux':
      final appImage = env['APPIMAGE'];
      return appImage == null || appImage.isEmpty
          ? null
          : AppImageInstaller(appImagePath: appImage);
    case 'macos':
      final marker = executable.indexOf('.app/Contents/');
      if (marker == -1) return null;
      return MacDmgInstaller(
        bundlePath: executable.substring(0, marker + 4),
        processId: processId ?? pid,
      );
    case 'windows':
      return WindowsExeInstaller(executablePath: executable);
  }
  return null;
}

final updateInstallerProvider = Provider<UpdateInstaller?>(
  (ref) => systemUpdateInstaller(),
);

/// Ends the app after an update was handed over; tests replace it.
final appExitProvider = Provider<void Function()>(
  (ref) =>
      () => exit(0),
);
