import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// The picture the user chose as a square PNG of [size] pixels: the biggest
/// centred square of it, scaled. Photos are far larger than the 512 KB the
/// server takes, and the avatar is shown at 72 px at most.
///
/// Throws a [FormatException] for bytes that are not an image the engine can
/// read.
Future<Uint8List> squareAvatarPng(List<int> source, {int size = 256}) async {
  final ui.Image image;
  try {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(source));
    image = (await codec.getNextFrame()).image;
  } on Object {
    throw const FormatException('The file is not an image that can be read');
  }
  final side = math.min(image.width, image.height).toDouble();
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    ui.Rect.fromLTWH(
      (image.width - side) / 2,
      (image.height - side) / 2,
      side,
      side,
    ),
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final square = await recorder.endRecording().toImage(size, size);
  final data = await square.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  square.dispose();
  if (data == null) {
    throw const FormatException('The picture could not be prepared');
  }
  return data.buffer.asUint8List();
}
