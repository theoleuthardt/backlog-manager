import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:backlog_manager/platform/desktop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Saves a file where the user chooses, with the save dialog of the system.
/// Tests replace it.
abstract interface class FileSaver {
  /// Asks for a place and writes [bytes] there; false when the user cancelled.
  Future<bool> save({required String suggestedName, required List<int> bytes});

  /// Whether [save] hands the file to the share sheet instead of writing it,
  /// so a page says "shared" rather than "saved".
  bool get shares;
}

class SystemFileSaver implements FileSaver {
  const SystemFileSaver();

  @override
  bool get shares => false;

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

/// The MIME type the share sheet is told for [name], from its extension.
String mimeTypeFor(String name) {
  final extension = name.contains('.')
      ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
      : '';
  return switch (extension) {
    'csv' => 'text/csv',
    'json' => 'application/json',
    _ => 'application/octet-stream',
  };
}

/// Writes [bytes] as [name] into the share folder of [temp], after emptying
/// it of the files of the share before. Only the last part of [name] counts
/// (a backup's name comes from the server), so no name can write outside the
/// folder.
Future<File> stageSharedFile(
  Directory temp,
  String name,
  List<int> bytes,
) async {
  final folder = Directory('${temp.path}/blm-share');
  if (folder.existsSync()) await folder.delete(recursive: true);
  await folder.create(recursive: true);
  final last = name.split(RegExp(r'[/\\]')).last;
  final safe = last.isEmpty || last == '.' || last == '..' ? 'file' : last;
  final file = File('${folder.path}/$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// Android and iOS have no save dialog: the file goes to the share sheet,
/// from which it can be saved to Files or Drive, mailed or sent; false when
/// the user dismissed it. On an iPad the sheet needs a place to point at, the
/// middle of the screen. The file is staged in a folder of its own in the
/// temporary directory, emptied before the next share, so backups and exports
/// do not pile up there.
class ShareFileSaver implements FileSaver {
  const ShareFileSaver();

  @override
  bool get shares => true;

  @override
  Future<bool> save({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    final view = PlatformDispatcher.instance.implicitView;
    final size = view == null
        ? Size.zero
        : view.physicalSize / view.devicePixelRatio;
    final staged = await stageSharedFile(
      Directory.systemTemp,
      suggestedName,
      bytes,
    );
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(staged.path, mimeType: mimeTypeFor(suggestedName))],
        sharePositionOrigin: Rect.fromCenter(
          center: size.center(Offset.zero),
          width: 1,
          height: 1,
        ),
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}

final fileSaverProvider = Provider<FileSaver>(
  (ref) => ref.watch(isDesktopProvider)
      ? const SystemFileSaver()
      : const ShareFileSaver(),
);
