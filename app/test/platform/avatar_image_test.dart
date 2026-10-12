import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:backlog_manager/platform/avatar_image.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> sourcePng({required int width, required int height}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    )
    ..drawRect(
      ui.Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF0000FF),
    );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('crops the centre square of a wide picture and scales it', () async {
    final png = await squareAvatarPng(
      await sourcePng(width: 400, height: 200),
      size: 64,
    );

    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    expect((image.width, image.height), (64, 64));
    final pixels = (await image.toByteData())!;
    int redAt(int x, int y) => pixels.getUint8((y * 64 + x) * 4);
    int blueAt(int x, int y) => pixels.getUint8((y * 64 + x) * 4 + 2);
    expect(redAt(8, 32), greaterThan(200));
    expect(blueAt(56, 32), greaterThan(200));
  });

  test('is a PNG far below the limit of the server', () async {
    final png = await squareAvatarPng(
      await sourcePng(width: 1200, height: 900),
    );

    expect(png.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
    expect(png.length, lessThan(512 * 1024));
  });

  test('refuses bytes that are not an image', () async {
    await expectLater(
      squareAvatarPng([1, 2, 3, 4]),
      throwsA(isA<FormatException>()),
    );
  });
}
