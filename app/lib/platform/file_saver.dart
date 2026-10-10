import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saves a file where the user chooses, with the save dialog of the system.
/// Tests replace it.
abstract interface class FileSaver {
  /// Asks for a place and writes [bytes] there; false when the user cancelled.
  Future<bool> save({required String suggestedName, required List<int> bytes});
}

class SystemFileSaver implements FileSaver {
  const SystemFileSaver();

  @override
  Future<bool> save({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return false;
    await XFile.fromData(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      name: suggestedName,
    ).saveTo(location.path);
    return true;
  }
}

final fileSaverProvider = Provider<FileSaver>((ref) => const SystemFileSaver());
