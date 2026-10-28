import 'package:backlog_manager/platform/csv_file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets the user choose a picture with the open dialog of the system. Tests
/// replace it.
abstract interface class ImageFilePicker {
  /// The chosen file, or null when the user cancelled.
  Future<PickedFile?> pick();
}

/// Pictures for the open dialog of every system: the extensions for the
/// desktop, the MIME types for Android and the type identifier for iOS, which
/// refuses a group without one.
const imageTypeGroup = XTypeGroup(
  label: 'Pictures',
  extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
  mimeTypes: [
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
    'image/bmp',
  ],
  uniformTypeIdentifiers: ['public.image'],
);

class SystemImageFilePicker implements ImageFilePicker {
  const SystemImageFilePicker();

  @override
  Future<PickedFile?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [imageTypeGroup]);
    return file == null ? null : PickedFile.fromXFile(file);
  }
}

final imageFilePickerProvider = Provider<ImageFilePicker>(
  (ref) => const SystemImageFilePicker(),
);
