import 'package:backlog_manager/platform/csv_file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets the user choose a picture with the open dialog of the system. Tests
/// replace it.
abstract interface class ImageFilePicker {
  /// The chosen file, or null when the user cancelled.
  Future<PickedFile?> pick();
}

class SystemImageFilePicker implements ImageFilePicker {
  const SystemImageFilePicker();

  @override
  Future<PickedFile?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Pictures',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
        ),
      ],
    );
    return file == null ? null : PickedFile.fromXFile(file);
  }
}

final imageFilePickerProvider = Provider<ImageFilePicker>(
  (ref) => const SystemImageFilePicker(),
);
