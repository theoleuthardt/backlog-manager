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
}
