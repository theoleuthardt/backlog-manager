import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the user chose or dropped: its name and a way to read its bytes.
class PickedFile {
  const PickedFile({required this.name, required this.readBytes});

  factory PickedFile.fromXFile(XFile file) =>
      PickedFile(name: file.name, readBytes: file.readAsBytes);

  final String name;
  final Future<List<int>> Function() readBytes;
}

/// Lets the user choose a CSV file with the open dialog of the system. Tests
/// replace it.
abstract interface class CsvFilePicker {
  /// The chosen file, or null when the user cancelled.
  Future<PickedFile?> pick();
}

class SystemCsvFilePicker implements CsvFilePicker {
  const SystemCsvFilePicker();

  @override
  Future<PickedFile?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    return file == null ? null : PickedFile.fromXFile(file);
  }
}

final csvFilePickerProvider = Provider<CsvFilePicker>(
  (ref) => const SystemCsvFilePicker(),
);
