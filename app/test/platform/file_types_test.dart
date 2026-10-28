import 'package:backlog_manager/platform/csv_file_picker.dart';
import 'package:backlog_manager/platform/image_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a CSV file can be picked on every platform', () {
    expect(csvTypeGroup.extensions, ['csv']);
    expect(csvTypeGroup.mimeTypes, contains('text/csv'));
    expect(
      csvTypeGroup.uniformTypeIdentifiers,
      contains('public.comma-separated-values-text'),
    );
  });

  test('a picture can be picked on every platform', () {
    expect(imageTypeGroup.extensions, containsAll(['png', 'jpg', 'webp']));
    expect(imageTypeGroup.mimeTypes, containsAll(['image/png', 'image/jpeg']));
    expect(imageTypeGroup.uniformTypeIdentifiers, contains('public.image'));
  });
}
