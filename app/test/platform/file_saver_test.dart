import 'dart:io';

import 'package:backlog_manager/platform/desktop.dart';
import 'package:backlog_manager/platform/file_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FileSaver saverOn({required bool desktop}) {
  final container = ProviderContainer(
    overrides: [isDesktopProvider.overrideWithValue(desktop)],
  );
  addTearDown(container.dispose);
  return container.read(fileSaverProvider);
}

void main() {
  test('the desktop asks for a place with the save dialog', () {
    expect(saverOn(desktop: true), isA<SystemFileSaver>());
  });

  test('a phone hands the file to the share sheet', () {
    expect(saverOn(desktop: false), isA<ShareFileSaver>());
  });

  test('the share sheet gets the MIME type of the file', () {
    expect(mimeTypeFor('backlog.csv'), 'text/csv');
    expect(mimeTypeFor('space-backup.json'), 'application/json');
    expect(mimeTypeFor('notes'), 'application/octet-stream');
  });

  test('a shared file replaces the one shared before', () async {
    final temp = Directory.systemTemp.createTempSync('blm-test');
    addTearDown(() => temp.deleteSync(recursive: true));

    final first = await stageSharedFile(temp, 'backup-1.json', [1]);
    final second = await stageSharedFile(temp, 'backup-2.json', [2, 3]);

    expect(first.existsSync(), isFalse);
    expect(second.readAsBytesSync(), [2, 3]);
  });
}
