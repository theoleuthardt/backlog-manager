import 'package:backlog_manager/platform/trailer_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trailerPage', () {
    final page = trailerPage(
      Uri.parse('https://www.youtube-nocookie.com/embed/abc123?autoplay=1'),
    );

    test('puts the embed in a frame that fills the page', () {
      expect(
        page,
        contains('src="https://www.youtube-nocookie.com/embed/abc123?'),
      );
      expect(page, contains('autoplay=1'));
      expect(page, contains('<iframe'));
      expect(page, contains('allowfullscreen'));
    });

    test('names the app as the embedding origin, not YouTube itself', () {
      expect(trailerOrigin, isNot(contains('youtube')));
      expect(page, contains('referrerpolicy="strict-origin"'));
      expect(
        page,
        contains('origin=${Uri.encodeQueryComponent(trailerOrigin)}'),
      );
    });

    test('escapes the address so it cannot leave the attribute', () {
      final hostile = trailerPage(
        Uri.parse('https://www.youtube.com/embed/a"onload="x'),
      );

      expect(hostile, isNot(contains('"onload="x')));
    });
  });
}
