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

/// CSV files for the open dialog of every system: the extension for the
/// desktop, the MIME types for Android and the type identifier for iOS, which
/// refuses a group without one.
const csvTypeGroup = XTypeGroup(
  label: 'CSV',
  extensions: ['csv'],
  mimeTypes: ['text/csv', 'text/comma-separated-values', 'application/csv'],
  uniformTypeIdentifiers: ['public.comma-separated-values-text'],
);

class SystemCsvFilePicker implements CsvFilePicker {
  const SystemCsvFilePicker();

  @override
  Future<PickedFile?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [csvTypeGroup]);
    return file == null ? null : PickedFile.fromXFile(file);
  }
}

final csvFilePickerProvider = Provider<CsvFilePicker>(
  (ref) => const SystemCsvFilePicker(),
);
